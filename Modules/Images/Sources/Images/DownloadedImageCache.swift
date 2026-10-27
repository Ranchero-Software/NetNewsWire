//
//  DownloadedImageCache.swift
//  Images
//
//  Created by Brent Simmons on 10/26/26.
//

import Foundation
import os
import RSCore
import RSWeb
import ActivityLog

/// Downloads each image URL once and keeps one copy on disk, shared by icons and thumbnails.
///
/// The copy is scaled down to `maxPixelSize`, the largest size anything displays,
/// or kept as is when it’s already smaller. `ImageDownloader` and `ArticleThumbnailFinder`
/// make their own sizes from it.
/// Requests for a URL that’s already being read or downloaded share that work.
///
/// Copies on disk are kept until they total more than `limit`. Then the least recently used are
/// deleted from disk, except those used in the last few days, which may still be on screen.
/// `hardLimit` caps those too. That’s checked at launch and whenever a download goes over the limit.
///
/// Icons can change at the same URL, so callers that show icons pass `checksForUpdates`.
/// An icon used after its `nextCheck` date is still used, and the server is asked in the
/// background whether it changed. Unchanged icons cost a 304 response, not the image again.
/// Other images, such as thumbnails, keep the version first downloaded.
@MainActor final class DownloadedImageCache {

	static let shared = DownloadedImageCache()

	/// The size of large thumbnails, the largest images displayed.
	nonisolated static let maxPixelSize = 1200

	private static let folderName = "DownloadedImages"
	nonisolated private static let compressionQuality = 0.8
	private static let maximumConcurrentLimitedDownloads = 4

	#if os(macOS)
	private static let limit = ByteLimit(maximumByteCount: 300 * 1024 * 1024)
	private static let hardLimit = ByteLimit(maximumByteCount: 1024 * 1024 * 1024)
	#else
	private static let limit = ByteLimit(maximumByteCount: 150 * 1024 * 1024)
	private static let hardLimit = ByteLimit(maximumByteCount: 500 * 1024 * 1024)
	#endif
	/// When recently used images keep the total over `limit`, the next pass waits for this much more.
	private static let byteCountBetweenPasses = limit.maximumByteCount / 10
	private static let readNoteInterval = TimeInterval(days: 1)
	/// Eight days, not seven, so checks spread across the days of the week.
	nonisolated private static let defaultCheckInterval = TimeInterval(days: 8)
	/// A server’s max-age is kept within these, so a misconfigured server isn’t asked too often.
	nonisolated private static let minimumCheckInterval = TimeInterval(days: 3)
	nonisolated private static let maximumCheckInterval = TimeInterval(days: 30)
	/// Images used this recently are removed only to stay under `hardLimit`.
	nonisolated private static let recentUseInterval = TimeInterval(days: 3)
	/// A file and its record are saved moments apart, so anything this recent may be mid-save.
	nonisolated private static let recentChangeInterval: TimeInterval = 60

	nonisolated private static let logger = Logger(subsystem: Logger.nnwSubsystem, category: "DownloadedImageCache")

	private let diskCache: BinaryDiskCache
	private let downloadLimiter = DownloadLimiter(maximumConcurrentDownloads: maximumConcurrentLimitedDownloads)
	private var tasks = [String: Task<Result<Data, ImageDownloadError>, Never>]() // url: task
	private var totalByteCount: Int? // Nil while a removal pass counts it
	private var removalByteCount = limit.maximumByteCount // A save that takes the total over this starts a pass
	private var readDatesNoted = [String: Date]() // url: date

	private init() {
		let folder = AppConfig.cacheSubfolder(named: Self.folderName)
		self.diskCache = BinaryDiskCache(folder: folder.path)

		Task {
			await self.removeImagesOverSizeLimit()
		}
	}

	/// The stored copy, read from disk or downloaded. Downloads that use the download limiter
	/// wait their turn, and don’t start when offline or in Low Data Mode.
	/// Activity log fires only when the request reaches the network.
	func imageData(for url: String, usesDownloadLimiter: Bool, checksForUpdates: Bool, activityOwner: ActivityOwner?, activityKind: ActivityKind?, activityDetail: String?) async throws(ImageDownloadError) -> Data {
		if let task = tasks[url] {
			return try await task.value.get()
		}

		let task = Task {
			await findImage(url, usesDownloadLimiter: usesDownloadLimiter, checksForUpdates: checksForUpdates, activityOwner: activityOwner, activityKind: activityKind, activityDetail: activityDetail)
		}
		tasks[url] = task
		let result = await task.value
		tasks[url] = nil
		return try result.get()
	}
}

private extension DownloadedImageCache {

	func findImage(_ url: String, usesDownloadLimiter: Bool, checksForUpdates: Bool, activityOwner: ActivityOwner?, activityKind: ActivityKind?, activityDetail: String?) async -> Result<Data, ImageDownloadError> {
		if let data = await Self.readFromDisk(diskCache, key: Self.diskKey(url)) {
			imageWasRead(url, checksForUpdates: checksForUpdates)
			return .success(data)
		}

		if usesDownloadLimiter {
			guard downloadLimiter.networkAllowsDownloads else {
				return .failure(ImageDownloadError(statusCode: nil, decodingFailed: false, isTransient: true))
			}
			await downloadLimiter.waitForTurn()
		}
		let result = await downloadImageFromNetwork(url, activityOwner: activityOwner, activityKind: activityKind, activityDetail: activityDetail)
		if usesDownloadLimiter {
			downloadLimiter.downloadDidFinish()
		}
		return result
	}

	func downloadImageFromNetwork(_ url: String, activityOwner: ActivityOwner?, activityKind: ActivityKind?, activityDetail: String?) async -> Result<Data, ImageDownloadError> {
		let activityLog = ActivityLog.shared
		if let activityOwner, let activityKind {
			activityLog.createActivity(owner: activityOwner, kind: activityKind, detail: activityDetail)
			activityLog.didStart(activityOwner, kind: activityKind)
		}

		do {
			let (data, downloadResponse) = try await downloadImage(url)
			if let activityOwner, let activityKind {
				let message = downloadResponse.data.map(ActivityLog.dataSizeMessage)
				activityLog.didComplete(activityOwner, kind: activityKind, message: message, returnedFromCache: downloadResponse.returnedFromCache)
			}
			ImageMetadataDatabase.shared.clearFailure(url: url)
			return .success(data)
		} catch {
			if let activityOwner, let activityKind {
				activityLog.didFail(activityOwner, kind: activityKind, error: error)
			}
			if !error.isTransient {
				ImageMetadataDatabase.shared.recordFailure(url: url, statusCode: error.statusCode)
			}
			return .failure(error)
		}
	}

	func downloadImage(_ url: String) async throws(ImageDownloadError) -> (Data, DownloadResponse) {
		guard let imageURL = URL(string: url) else {
			throw ImageDownloadError(statusCode: nil, decodingFailed: false, isTransient: false)
		}

		let downloadResponse: DownloadResponse
		do {
			// Not cached by Downloader, since the copy on disk is the cache.
			downloadResponse = try await Downloader.shared.download(imageURL, userAgentStyle: .browser, cachesResponse: false)
		} catch {
			Self.logger.error("Error downloading image at \(url) \(error.localizedDescription)")
			throw ImageDownloadError(statusCode: nil, decodingFailed: false, isTransient: true)
		}

		let httpResponse = downloadResponse.response as? HTTPURLResponse
		let statusCode = httpResponse?.statusCode
		if let data = downloadResponse.data, !data.isEmpty, let response = downloadResponse.response, response.statusIsOK {
			let storedData = await saveImage(data, url: url, httpResponse: httpResponse)
			return (storedData, downloadResponse)
		}

		// 2xx with empty / missing body — server said OK but gave us no image bytes.
		if let response = downloadResponse.response, response.statusIsOK {
			throw ImageDownloadError(statusCode: statusCode, decodingFailed: true, isTransient: false)
		}
		var isTransient = true
		if let statusCode {
			isTransient = statusCode >= 500 && statusCode <= 599
		}
		throw ImageDownloadError(statusCode: statusCode, decodingFailed: false, isTransient: isTransient)
	}

	/// Returns the stored data.
	func saveImage(_ data: Data, url: String, httpResponse: HTTPURLResponse?) async -> Data {
		let storedImage = await Self.storedImage(data)
		await Self.saveToDisk(diskCache, key: Self.diskKey(url), data: storedImage.data)
		var conditionalGetInfo: HTTPConditionalGetInfo?
		if let httpResponse {
			conditionalGetInfo = HTTPConditionalGetInfo(urlResponse: httpResponse)
		}
		let nextCheck = Self.nextCheck(httpResponse, hasValidators: conditionalGetInfo != nil)
		ImageMetadataDatabase.shared.saveDownloadedImage(DownloadedImageRecord(url: url, byteCount: storedImage.data.count, pixelSize: storedImage.pixelSize, conditionalGetInfo: conditionalGetInfo, nextCheck: nextCheck))
		imageWasSaved(byteCount: storedImage.data.count)
		return storedImage.data
	}

	/// At most once a day per image: saves the access date, which orders images for removal,
	/// and, when `checksForUpdates`, checks with the server if the copy is due.
	func imageWasRead(_ url: String, checksForUpdates: Bool) {
		let now = Date()
		if let readDate = readDatesNoted[url], now.timeIntervalSince(readDate) < Self.readNoteInterval {
			return
		}
		readDatesNoted[url] = now
		ImageMetadataDatabase.shared.saveDownloadedImageAccessDate(url: url)
		guard checksForUpdates else {
			return
		}
		Task {
			await revalidateIfDue(url)
		}
	}

	// MARK: - Revalidating Images

	/// Waits behind other downloads using the download limiter.
	/// A network error leaves `nextCheck` as is, so the next day’s use tries again.
	func revalidateIfDue(_ url: String) async {
		guard let validation = await ImageMetadataDatabase.shared.fetchDownloadedImageValidation(url: url), validation.nextCheck <= Date() else {
			return
		}
		guard let imageURL = URL(string: url), downloadLimiter.networkAllowsDownloads else {
			return
		}

		await downloadLimiter.waitForTurn()
		defer {
			downloadLimiter.downloadDidFinish()
		}

		var urlRequest = URLRequest(url: imageURL)
		validation.conditionalGetInfo?.addRequestHeadersToURLRequest(&urlRequest)
		let downloadResponse: DownloadResponse
		do {
			downloadResponse = try await Downloader.shared.download(urlRequest, userAgentStyle: .browser, cachesResponse: false)
		} catch {
			return
		}

		let httpResponse = downloadResponse.response as? HTTPURLResponse
		if let data = downloadResponse.data, !data.isEmpty, let httpResponse, httpResponse.statusIsOK {
			Self.logger.info("Replaced changed image at \(url)")
			_ = await saveImage(data, url: url, httpResponse: httpResponse)
			return
		}

		// 304 Not Modified, or an error response: keep the copy and check again later.
		ImageMetadataDatabase.shared.saveDownloadedImageNextCheck(url: url, nextCheck: Self.nextCheck(httpResponse, hasValidators: validation.conditionalGetInfo != nil))
	}

	// MARK: - Removing Images

	func imageWasSaved(byteCount: Int) {
		guard let totalByteCount else {
			return
		}
		let updatedTotalByteCount = totalByteCount + byteCount
		self.totalByteCount = updatedTotalByteCount
		if updatedTotalByteCount > removalByteCount {
			Task {
				await removeImagesOverSizeLimit()
			}
		}
	}

	/// Removes the least recently used images until the total is `byteCountAfterRemoval`.
	/// Also removes files with no record and records with no file, so the total matches the disk.
	/// Saves don’t start another pass while `totalByteCount` is nil.
	func removeImagesOverSizeLimit() async {
		totalByteCount = nil
		let startDate = Date()

		let records = await ImageMetadataDatabase.shared.fetchDownloadedImageUsageByLeastRecentAccess()
		let fileDates = await Self.fileModificationDates(diskCache)
		let removal = Self.imageRemoval(records: records, fileDates: fileDates, now: startDate, limit: Self.limit, hardLimit: Self.hardLimit)

		totalByteCount = removal.remainingByteCount
		removalByteCount = max(Self.limit.maximumByteCount, removal.remainingByteCount + Self.byteCountBetweenPasses)
		guard !removal.urls.isEmpty || !removal.keys.isEmpty else {
			return
		}
		ImageMetadataDatabase.shared.deleteDownloadedImages(urls: removal.urls)
		await Self.deleteFromDisk(diskCache, keys: removal.keys)
		Self.logger.info("Removed \(removal.keys.count) files and \(removal.urls.count) records. \(removal.remainingByteCount) bytes remain.")
	}

	/// Data that ImageIO can’t read, such as SVG, is kept as is, since `RSImage` may still read it.
	@concurrent static func storedImage(_ data: Data) async -> (data: Data, pixelSize: (width: Int, height: Int)?) {
		let storedData = RSImage.scaledImageData(data, maxPixelSize: maxPixelSize, format: .jpeg(compressionQuality: compressionQuality)) ?? data
		return (data: storedData, pixelSize: RSImage.largestFramePixelSize(storedData))
	}

	@concurrent static func readFromDisk(_ diskCache: BinaryDiskCache, key: String) async -> Data? {
		guard let data = diskCache[key], !data.isEmpty else {
			return nil
		}
		return data
	}

	@concurrent static func saveToDisk(_ diskCache: BinaryDiskCache, key: String, data: Data) async {
		diskCache[key] = data
	}

	/// Keys are file names.
	@concurrent static func fileModificationDates(_ diskCache: BinaryDiskCache) async -> [String: Date] {
		let folderURL = URL(fileURLWithPath: diskCache.folder)
		guard let fileURLs = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.contentModificationDateKey]) else {
			return [:]
		}
		var fileDates = [String: Date]()
		for fileURL in fileURLs {
			fileDates[fileURL.lastPathComponent] = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
		}
		return fileDates
	}

	@concurrent static func deleteFromDisk(_ diskCache: BinaryDiskCache, keys: Set<String>) async {
		for key in keys {
			diskCache[key] = nil
		}
	}
}

// MARK: - Disk Keys, Check Dates, and Removal

extension DownloadedImageCache {

	nonisolated static func diskKey(_ url: String) -> String {
		url.md5String
	}

	/// Without an ETag or Last-Modified, a check downloads the whole image, so it waits the longest.
	nonisolated static func nextCheck(_ httpResponse: HTTPURLResponse?, hasValidators: Bool) -> Date {
		var interval = defaultCheckInterval
		if !hasValidators {
			interval = maximumCheckInterval
		} else if let httpResponse, let cacheControlInfo = CacheControlInfo(urlResponse: httpResponse) {
			interval = min(max(cacheControlInfo.maxAge, minimumCheckInterval), maximumCheckInterval)
		}
		return Date().addingTimeInterval(interval)
	}

	struct ByteLimit {
		let maximumByteCount: Int
		/// Removing more than needed means removal doesn’t run again with every download.
		let byteCountAfterRemoval: Int

		init(maximumByteCount: Int) {
			self.maximumByteCount = maximumByteCount
			self.byteCountAfterRemoval = maximumByteCount / 5 * 4
		}
	}

	struct ImageRemoval: Equatable {
		let urls: [String] // Records to delete
		let keys: Set<String> // Files to delete
		let remainingByteCount: Int
	}

	/// `records` are least recently accessed first. Files with no record and records with no file
	/// are removed. Then, when over `limit`, the least recently accessed images not used recently
	/// are removed, and when still over `hardLimit`, the least recently accessed of the rest.
	/// Nothing changed in the last minute is removed, since it may be in the middle of being saved.
	nonisolated static func imageRemoval(records: [DownloadedImageUsage], fileDates: [String: Date], now: Date, limit: ByteLimit, hardLimit: ByteLimit) -> ImageRemoval {
		let recentChangeDate = now.addingTimeInterval(-recentChangeInterval)
		let recentUseDate = now.addingTimeInterval(-recentUseInterval)

		var recordsToKeep = [(record: DownloadedImageUsage, key: String)]()
		var recordedKeys = Set<String>()
		var urls = [String]()
		for record in records {
			let key = diskKey(record.url)
			recordedKeys.insert(key)
			if fileDates[key] == nil && record.lastAccessed < recentChangeDate {
				urls.append(record.url)
			} else {
				recordsToKeep.append((record: record, key: key))
			}
		}
		var keys = Set(fileDates.filter { !recordedKeys.contains($0.key) && $0.value < recentChangeDate }.keys)
		var byteCount = recordsToKeep.reduce(0) { $0 + $1.record.byteCount }

		func removeLeastRecentlyUsed(accessedBefore date: Date, limit: ByteLimit) {
			guard byteCount > limit.maximumByteCount else {
				return
			}
			for (record, key) in recordsToKeep {
				if byteCount <= limit.byteCountAfterRemoval || record.lastAccessed >= date {
					break
				}
				if keys.contains(key) {
					continue
				}
				urls.append(record.url)
				keys.insert(key)
				byteCount -= record.byteCount
			}
		}
		removeLeastRecentlyUsed(accessedBefore: recentUseDate, limit: limit)
		removeLeastRecentlyUsed(accessedBefore: recentChangeDate, limit: hardLimit)

		return ImageRemoval(urls: urls, keys: keys, remainingByteCount: byteCount)
	}
}
