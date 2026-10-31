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

extension Notification.Name {
	/// Posted when a check with the server replaces the stored copy of an image with a changed one.
	/// userInfo key: `DownloadedImageCache.urlKey`.
	static let downloadedImageDidChange = Notification.Name("DownloadedImageDidChange")
}

/// Downloads each image URL once and keeps one copy on disk, shared by icons and thumbnails.
///
/// The copy is the image as downloaded, since the article view shows it at full size.
/// `ImageDownloader` and `ArticleThumbnailFinder` make their own sizes from it.
/// Requests for a URL that’s already being read or downloaded share that work.
///
/// A copy made from an image, such as a scaled icon, can be stored next to it with a suffix.
/// It’s kept while the image is, and removed with it. It doesn’t count toward the limits.
///
/// Copies on disk are kept until they total more than `limit`. Then the least recently used are
/// deleted from disk, except those used in the last few days, which may still be on screen.
/// `hardLimit` caps those too. That’s checked at launch and whenever a download goes over the limit.
///
/// Icons can change at the same URL, so callers that show icons pass `checksForUpdates`.
/// An icon used after its `nextCheck` date is still used, and the server is asked in the
/// background whether it changed. Unchanged icons cost a 304 response, not the image again.
/// Other images, such as thumbnails, keep the version first downloaded.
///
/// After a transient failure, such as a timeout or a 5xx response, the URL isn’t requested again
/// until a retry date. After a 429, a 503, or no response, nothing else on its host is requested
/// either. The wait starts at a minute and doubles with each failure after a wait ends, up to an hour,
/// or is the server’s Retry-After when that’s longer.
///
/// A URL that returned something other than an image isn’t requested again until the network status changes.
@MainActor final class DownloadedImageCache {

	static let shared = DownloadedImageCache()
	static let urlKey = "url"
	/// Scaled icons are saved next to their originals, so they aren’t rescaled after a memory cache is emptied.
	static let scaledIconSuffix = String(RSImage.maxIconPixelSize)

	private static let folderName = "DownloadedImages"
	private static let svgMIMEType = "image/svg+xml"
	private static let maximumConcurrentLimitedDownloads = 4
	/// Requests to one HTTP/1.1 host run one at a time, so a stalled host could otherwise hold every slot.
	private static let maximumDownloadsPerHost = 2
	/// A few screens of thumbnails.
	private static let maximumWaitingLimitedDownloads = 60
	/// Larger images aren’t saved for the timeline. The article view and icons have no limit.
	private static let maximumLimitedDownloadByteCount = 25 * 1024 * 1024

	#if os(macOS)
	private static let limit = ByteLimit(maximumByteCount: 300 * 1024 * 1024)
	private static let hardLimit = ByteLimit(maximumByteCount: 1024 * 1024 * 1024)
	#else
	private static let limit = ByteLimit(maximumByteCount: 150 * 1024 * 1024)
	private static let hardLimit = ByteLimit(maximumByteCount: 500 * 1024 * 1024)
	#endif
	/// When recently used images keep the total over `limit`, the next pass waits for this much more.
	private static let byteCountBetweenPasses = limit.maximumByteCount / 4
	private static let readNoteInterval = TimeInterval(days: 1)
	/// Past this, `readDatesNoted` is emptied, so a session lasting weeks doesn’t keep every URL it used.
	private static let maximumReadDatesNotedCount = 10_000
	/// Eight days, not seven, so checks spread across the days of the week.
	nonisolated private static let defaultCheckInterval = TimeInterval(days: 8)
	/// A server’s max-age is kept within these, so a misconfigured server isn’t asked too often.
	nonisolated private static let minimumCheckInterval = TimeInterval(days: 3)
	nonisolated private static let maximumCheckInterval = TimeInterval(days: 30)
	/// Check intervals vary by up to this fraction either way, so images downloaded together aren’t all checked together.
	nonisolated private static let checkIntervalJitter = 0.2
	/// Images used this recently are removed only to stay under `hardLimit`.
	nonisolated private static let recentUseInterval = TimeInterval(days: 3)
	/// A file and its record are saved moments apart, so anything this recent may be mid-save.
	nonisolated private static let recentChangeInterval: TimeInterval = 60
	/// Disk keys are hex, so this can’t appear in an image’s own key.
	nonisolated private static let derivedKeySeparator: Character = "-"
	nonisolated private static let initialRetryDelay: TimeInterval = 60
	nonisolated private static let maximumRetryDelay: TimeInterval = 60 * 60

	nonisolated private static let logger = Logger(subsystem: Logger.nnwSubsystem, category: "DownloadedImageCache")

	private let diskCache: BinaryDiskCache
	private let downloadQueue = ThumbnailTaskQueue(maximumRunningCount: maximumConcurrentLimitedDownloads, maximumWaitingCount: maximumWaitingLimitedDownloads, maximumRunningCountPerGroup: maximumDownloadsPerHost)
	private var tasks = [String: Task<Result<Data, ImageDownloadError>, Never>]() // url: task
	private var totalByteCount: Int? // Nil while a removal pass counts it
	private var removalByteCount = limit.maximumByteCount // A save that takes the total over this starts a pass
	private var readDatesNoted = [String: Date]() // url: date
	private var retryDelays = [String: RetryDelay]() // url: wait after its last transient failure
	private var hostRetryDelays = [String: RetryDelay]() // lowercased host: wait after its last transient failure
	private var urlsThatReturnedNonImage = Set<String>()

	private init() {
		let folder = AppConfig.cacheSubfolder(named: Self.folderName)
		self.diskCache = BinaryDiskCache(folder: folder.path)

		NotificationCenter.default.addObserver(self, selector: #selector(handleNetworkStatusDidChange(_:)), name: .networkStatusDidChange, object: nil)

		Task {
			await self.removeImagesOverSizeLimit()
		}
	}

	/// False when offline or in Low Data Mode.
	static var networkAllowsDownloads: Bool {
		NetworkMonitor.shared.isConnected && !NetworkMonitor.shared.isConstrained
	}

	/// The stored copy, read from disk or downloaded. With a `downloadPriority`, a download
	/// waits its turn in the download queue, and doesn’t start when offline or in Low Data Mode.
	/// A prefetch also doesn’t start on an expensive network or in Low Power Mode.
	/// Without a `downloadPriority`, it starts right away, as does a waiting download for the same URL.
	/// Activity log fires only when the request reaches the network.
	func imageData(for url: String, downloadPriority: ThumbnailPriority?, checksForUpdates: Bool, activityOwner: ActivityOwner?, activityKind: ActivityKind?, activityDetail: String?) async throws(ImageDownloadError) -> Data {
		if let task = tasks[url] {
			switch downloadPriority {
			case .visible:
				prioritizeDownload(for: url)
			case nil:
				downloadQueue.startNow(key: url)
			case .prefetch:
				break
			}
			return try await task.value.get()
		}

		let task = Task {
			await findImage(url, downloadPriority: downloadPriority, checksForUpdates: checksForUpdates, activityOwner: activityOwner, activityKind: activityKind, activityDetail: activityDetail)
		}
		tasks[url] = task
		let result = await task.value
		tasks[url] = nil
		return try result.get()
	}

	/// Moves a waiting download to the front, for an image that just became visible.
	func prioritizeDownload(for url: String) {
		downloadQueue.prioritize(key: url)
	}

	/// True when the URL returned something other than an image, and the network status hasn’t changed since.
	func returnedNonImage(_ url: String) -> Bool {
		urlsThatReturnedNonImage.contains(url)
	}

	/// A copy made from the image at `url`, such as a scaled icon. Nil when none has been saved.
	func derivedImageData(for url: String, suffix: String) async -> Data? {
		await Self.readFromDisk(diskCache, key: Self.derivedDiskKey(url, suffix: suffix))
	}

	func saveDerivedImageData(_ data: Data, for url: String, suffix: String) async {
		try? await Self.saveToDisk(diskCache, key: Self.derivedDiskKey(url, suffix: suffix), data: data)
	}

	/// At most once a day per image: saves the access date, which orders images for removal,
	/// and, when `checksForUpdates`, checks with the server if the copy is due.
	/// Callers that keep images in memory call this on memory hits too, so images in use aren’t removed first.
	func imageWasUsed(_ url: String, checksForUpdates: Bool) {
		let now = Date()
		if let readDate = readDatesNoted[url], now.timeIntervalSince(readDate) < Self.readNoteInterval {
			return
		}
		if readDatesNoted.count >= Self.maximumReadDatesNotedCount {
			readDatesNoted.removeAll()
		}
		readDatesNoted[url] = now
		ImageDatabase.shared.saveDownloadedImageAccessDate(url: url)
		guard checksForUpdates else {
			return
		}
		Task {
			await revalidateIfDue(url)
		}
	}

	/// Failures while offline say nothing about the servers, so retries can start right away,
	/// except where a server asked for a wait with Retry-After.
	/// What wasn’t an image may have been a captive portal’s login page.
	@objc func handleNetworkStatusDidChange(_ notification: Notification) {
		retryDelays = retryDelays.filter { $0.value.isFromRetryAfter }
		hostRetryDelays = hostRetryDelays.filter { $0.value.isFromRetryAfter }
		urlsThatReturnedNonImage.removeAll()
	}
}

private extension DownloadedImageCache {

	func findImage(_ url: String, downloadPriority: ThumbnailPriority?, checksForUpdates: Bool, activityOwner: ActivityOwner?, activityKind: ActivityKind?, activityDetail: String?) async -> Result<Data, ImageDownloadError> {
		if let data = await Self.readFromDisk(diskCache, key: Self.diskKey(url)) {
			imageWasUsed(url, checksForUpdates: checksForUpdates)
			return .success(data)
		}

		if urlsThatReturnedNonImage.contains(url) {
			return .failure(ImageDownloadError(statusCode: nil, decodingFailed: true, isTransient: true))
		}
		if isWaitingToRetry(url) {
			return .failure(ImageDownloadError(statusCode: nil, decodingFailed: false, isTransient: true))
		}
		let host = Self.host(url)
		if let downloadPriority {
			guard Self.networkAllowsDownload(priority: downloadPriority) else {
				return .failure(ImageDownloadError(statusCode: nil, decodingFailed: false, isTransient: true))
			}
			switch await downloadQueue.waitForTurn(key: url, group: host, priority: downloadPriority) {
			case .dropped:
				return .failure(ImageDownloadError(statusCode: nil, decodingFailed: false, isTransient: true))
			case .start(let currentPriority):
				// The network or a retry wait may have changed while this was queued.
				guard !isWaitingToRetry(url), Self.networkAllowsDownload(priority: currentPriority) else {
					downloadQueue.taskDidFinish(group: host)
					return .failure(ImageDownloadError(statusCode: nil, decodingFailed: false, isTransient: true))
				}
			case .startNow:
				break
			}
		}
		let maximumByteCount = downloadPriority == nil ? nil : Self.maximumLimitedDownloadByteCount
		let result = await downloadImageFromNetwork(url, maximumByteCount: maximumByteCount, activityOwner: activityOwner, activityKind: activityKind, activityDetail: activityDetail)
		if downloadPriority != nil {
			downloadQueue.taskDidFinish(group: host)
		}
		noteDownloadResult(result, url: url)
		return result
	}

	/// Prefetching also waits for a network that isn’t expensive, such as cellular, and for Low Power Mode to be off.
	static func networkAllowsDownload(priority: ThumbnailPriority) -> Bool {
		guard networkAllowsDownloads else {
			return false
		}
		switch priority {
		case .visible:
			return true
		case .prefetch:
			return !NetworkMonitor.shared.isExpensive && !ProcessInfo.processInfo.isLowPowerModeEnabled
		}
	}

	func isWaitingToRetry(_ url: String) -> Bool {
		let now = Date()
		if let retryDate = retryDelays[url]?.retryDate, retryDate > now {
			return true
		}
		if let host = Self.host(url), let retryDate = hostRetryDelays[host]?.retryDate, retryDate > now {
			return true
		}
		return false
	}

	/// Any response that isn’t a transient failure means the host is answering, so its wait ends.
	func noteDownloadResult(_ result: Result<Data, ImageDownloadError>, url: String) {
		let host = Self.host(url)
		guard case .failure(let error) = result, error.isTransient else {
			retryDelays[url] = nil
			if let host {
				hostRetryDelays[host] = nil
			}
			return
		}
		let now = Date()
		retryDelays[url] = Self.nextRetryDelay(after: retryDelays[url], retryAfter: error.retryAfter, now: now)
		if let host, Self.failureAppliesToHost(statusCode: error.statusCode) {
			hostRetryDelays[host] = Self.nextRetryDelay(after: hostRetryDelays[host], retryAfter: error.retryAfter, now: now)
		}
	}

	/// A host that’s rate limiting, overloaded, or not answering gets a wait. Other failures may be just the one URL.
	static func failureAppliesToHost(statusCode: Int?) -> Bool {
		guard let statusCode else {
			return true
		}
		return statusCode == HTTPResponseCode.tooManyRequests || statusCode == HTTPResponseCode.serviceUnavailable
	}

	static func host(_ url: String) -> String? {
		URL(string: url)?.host()?.lowercased(with: localeForLowercasing)
	}

	func downloadImageFromNetwork(_ url: String, maximumByteCount: Int?, activityOwner: ActivityOwner?, activityKind: ActivityKind?, activityDetail: String?) async -> Result<Data, ImageDownloadError> {
		let activityLog = ActivityLog.shared
		// Thumbnails log only failures, since a few screens of scrolling would otherwise push out the rest of the log.
		let logsOnlyFailure = activityOwner == .thumbnailDownloader
		if !logsOnlyFailure, let activityOwner, let activityKind {
			activityLog.createActivity(owner: activityOwner, kind: activityKind, detail: activityDetail)
			activityLog.didStart(activityOwner, kind: activityKind)
		}

		do {
			let (data, downloadResponse) = try await downloadImage(url, maximumByteCount: maximumByteCount)
			if !logsOnlyFailure, let activityOwner, let activityKind {
				let message = downloadResponse.data.map(ActivityLog.dataSizeMessage)
				activityLog.didComplete(activityOwner, kind: activityKind, message: message, returnedFromCache: downloadResponse.returnedFromCache)
			}
			ImageDatabase.shared.clearFailure(url: url)
			return .success(data)
		} catch {
			if let activityOwner, let activityKind {
				if logsOnlyFailure {
					activityLog.createActivity(owner: activityOwner, kind: activityKind, detail: activityDetail)
				}
				activityLog.didFail(activityOwner, kind: activityKind, error: error)
			}
			if !error.isTransient {
				ImageDatabase.shared.recordFailure(url: url, statusCode: error.statusCode)
			}
			return .failure(error)
		}
	}

	func downloadImage(_ url: String, maximumByteCount: Int?) async throws(ImageDownloadError) -> (Data, DownloadResponse) {
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
			if let maximumByteCount, data.count > maximumByteCount {
				throw ImageDownloadError(statusCode: statusCode, decodingFailed: false, isTransient: false, rejectedByteCount: data.count)
			}
			// Transient, since a captive portal’s login page would otherwise fail every image for days.
			guard try await saveImage(data, url: url, httpResponse: httpResponse) else {
				urlsThatReturnedNonImage.insert(url)
				throw ImageDownloadError(statusCode: statusCode, decodingFailed: true, isTransient: true)
			}
			return (data, downloadResponse)
		}

		// 2xx with empty / missing body — server said OK but gave us no image bytes.
		if let response = downloadResponse.response, response.statusIsOK {
			throw ImageDownloadError(statusCode: statusCode, decodingFailed: true, isTransient: false)
		}
		var isTransient = true
		if let statusCode {
			isTransient = Self.isTransient(statusCode: statusCode)
		}
		throw ImageDownloadError(statusCode: statusCode, decodingFailed: false, isTransient: isTransient, retryAfter: Self.retryAfter(httpResponse))
	}

	static func retryAfter(_ httpResponse: HTTPURLResponse?) -> TimeInterval? {
		guard let retryAfterValue = httpResponse?.value(forHTTPHeaderField: HTTPResponseHeader.retryAfter) else {
			return nil
		}
		return TimeInterval(retryAfterValue.trimmingCharacters(in: .whitespaces))
	}

	/// Returns false, and saves nothing, when the data isn’t an image, such as an HTML error page.
	/// SVG is saved, though ImageIO can’t read it.
	/// Throws a transient error, and records nothing, when the file can’t be written.
	func saveImage(_ data: Data, url: String, httpResponse: HTTPURLResponse?) async throws(ImageDownloadError) -> Bool {
		let pixelSize = await Self.pixelSize(data)
		guard pixelSize != nil || httpResponse?.mimeType == Self.svgMIMEType else {
			Self.logger.info("Didn’t save unreadable image at \(url)")
			return false
		}
		do {
			try await Self.saveToDisk(diskCache, key: Self.diskKey(url), data: data)
		} catch {
			Self.logger.error("Couldn’t write image from \(url): \(error.localizedDescription)")
			throw ImageDownloadError(statusCode: httpResponse?.statusCode, decodingFailed: false, isTransient: true)
		}
		var conditionalGetInfo: HTTPConditionalGetInfo?
		if let httpResponse {
			conditionalGetInfo = HTTPConditionalGetInfo(urlResponse: httpResponse)
		}
		let nextCheck = Self.nextCheck(httpResponse, hasValidators: conditionalGetInfo != nil)
		ImageDatabase.shared.saveDownloadedImage(DownloadedImageRecord(url: url, byteCount: data.count, pixelSize: pixelSize, conditionalGetInfo: conditionalGetInfo, nextCheck: nextCheck))
		imageWasSaved(byteCount: data.count)
		return true
	}

	// MARK: - Revalidating Images

	/// Doesn’t use the download queue, since icons aren’t limited either.
	/// A network that doesn’t allow downloads, a retry wait, or a network error leaves `nextCheck` as is, so the next day’s use tries again.
	func revalidateIfDue(_ url: String) async {
		guard Self.networkAllowsDownloads, !isWaitingToRetry(url) else {
			return
		}
		guard let validation = await ImageDatabase.shared.fetchDownloadedImageValidation(url: url), validation.nextCheck <= Date() else {
			return
		}
		guard let imageURL = URL(string: url) else {
			return
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
		if let data = downloadResponse.data, !data.isEmpty, let httpResponse, httpResponse.statusIsOK, (try? await saveImage(data, url: url, httpResponse: httpResponse)) == true {
			Self.logger.info("Replaced changed image at \(url)")
			await Self.deleteFromDisk(diskCache, keys: [Self.derivedDiskKey(url, suffix: Self.scaledIconSuffix)])
			NotificationCenter.default.post(name: .downloadedImageDidChange, object: self, userInfo: [Self.urlKey: url])
			return
		}

		if let httpResponse, Self.isTransient(statusCode: httpResponse.statusCode) {
			let error = ImageDownloadError(statusCode: httpResponse.statusCode, decodingFailed: false, isTransient: true, retryAfter: Self.retryAfter(httpResponse))
			noteDownloadResult(.failure(error), url: url)
		}

		// 304 Not Modified, an error response, not an image, or a failed write: keep the copy and check again later.
		ImageDatabase.shared.saveDownloadedImageNextCheck(url: url, nextCheck: Self.nextCheck(httpResponse, hasValidators: validation.conditionalGetInfo != nil))
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

		guard let records = await ImageDatabase.shared.fetchDownloadedImageUsageByLeastRecentAccess() else {
			Self.logger.error("Skipped removing images: couldn’t read the image records.")
			return
		}
		guard let fileDates = await Self.fileModificationDates(diskCache) else {
			Self.logger.error("Skipped removing images: couldn’t list the images folder.")
			return
		}
		let removal = await Self.imageRemoval(records: records, fileDates: fileDates, urlsInUse: Set(tasks.keys), now: startDate, limit: Self.limit, hardLimit: Self.hardLimit)

		totalByteCount = removal.remainingByteCount
		removalByteCount = max(Self.limit.maximumByteCount, removal.remainingByteCount + Self.byteCountBetweenPasses)
		guard !removal.urls.isEmpty || !removal.keys.isEmpty else {
			return
		}
		ImageDatabase.shared.deleteDownloadedImages(urls: removal.urls)
		await Self.deleteFromDisk(diskCache, keys: removal.keys)
		Self.logger.info("Removed \(removal.keys.count) files and \(removal.urls.count) records. \(removal.remainingByteCount) bytes remain.")
	}

	/// Nil when ImageIO can’t read the image, such as SVG.
	@concurrent static func pixelSize(_ data: Data) async -> (width: Int, height: Int)? {
		RSImage.largestFramePixelSize(data)
	}

	@concurrent static func readFromDisk(_ diskCache: BinaryDiskCache, key: String) async -> Data? {
		guard let data = diskCache[key], !data.isEmpty else {
			return nil
		}
		return data
	}

	@concurrent static func saveToDisk(_ diskCache: BinaryDiskCache, key: String, data: Data) async throws {
		try diskCache.setData(data, forKey: key)
	}

	@concurrent static func deleteFromDisk(_ diskCache: BinaryDiskCache, keys: Set<String>) async {
		for key in keys {
			diskCache[key] = nil
		}
	}
}

// MARK: - Disk Keys, Check Dates, and Removal

extension DownloadedImageCache {

	/// Keys are file names. Nil when the folder can’t be listed.
	@concurrent static func fileModificationDates(_ diskCache: BinaryDiskCache) async -> [String: Date]? {
		let folderURL = URL(fileURLWithPath: diskCache.folder)
		guard let fileURLs = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.contentModificationDateKey]) else {
			return nil
		}
		var fileDates = [String: Date]()
		for fileURL in fileURLs {
			fileDates[fileURL.lastPathComponent] = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
		}
		return fileDates
	}

	nonisolated static func diskKey(_ url: String) -> String {
		url.md5String
	}

	nonisolated static func derivedDiskKey(_ url: String, suffix: String) -> String {
		"\(diskKey(url))\(derivedKeySeparator)\(suffix)"
	}

	/// The key of the image a derived copy was made from, or `key` itself for an image.
	nonisolated static func baseDiskKey(_ key: String) -> String {
		guard let separatorIndex = key.firstIndex(of: derivedKeySeparator) else {
			return key
		}
		return String(key[..<separatorIndex])
	}

	nonisolated static func isTransient(statusCode: Int) -> Bool {
		(statusCode >= 500 && statusCode <= 599) || statusCode == HTTPResponseCode.tooManyRequests || statusCode == HTTPResponseCode.requestTimeout
	}

	struct RetryDelay {
		let retryDate: Date
		let delay: TimeInterval
		let isFromRetryAfter: Bool
	}

	/// Requests already running when a wait starts can fail during it, so the wait doubles only
	/// after it has ended. During a wait, only a longer Retry-After changes it.
	nonisolated static func nextRetryDelay(after previousRetryDelay: RetryDelay?, retryAfter: TimeInterval?, now: Date) -> RetryDelay {
		if let previousRetryDelay, previousRetryDelay.retryDate > now {
			guard let retryAfter, now.addingTimeInterval(retryAfter) > previousRetryDelay.retryDate else {
				return previousRetryDelay
			}
			return RetryDelay(retryDate: now.addingTimeInterval(retryAfter), delay: max(previousRetryDelay.delay, retryAfter), isFromRetryAfter: true)
		}

		var delay = initialRetryDelay
		if let previousRetryDelay {
			delay = min(previousRetryDelay.delay * 2, maximumRetryDelay)
		}
		if let retryAfter {
			delay = max(delay, retryAfter)
		}
		return RetryDelay(retryDate: now.addingTimeInterval(delay), delay: delay, isFromRetryAfter: retryAfter != nil)
	}

	/// Without an ETag or Last-Modified, a check downloads the whole image, so it waits the longest.
	nonisolated static func nextCheck(_ httpResponse: HTTPURLResponse?, hasValidators: Bool) -> Date {
		var interval = defaultCheckInterval
		if !hasValidators {
			interval = maximumCheckInterval
		} else if let httpResponse, let cacheControlInfo = CacheControlInfo(urlResponse: httpResponse) {
			interval = min(max(cacheControlInfo.maxAge, minimumCheckInterval), maximumCheckInterval)
		}
		interval *= Double.random(in: (1 - checkIntervalJitter)...(1 + checkIntervalJitter))
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
	/// are removed, along with derived copies of removed images. Then, when over `limit`, the least recently accessed images not used recently
	/// are removed, and when still over `hardLimit`, the least recently accessed of the rest.
	/// Nothing changed in the last minute is removed, since it may be in the middle of being saved.
	/// Images in `urlsInUse` are being read or downloaded, so they’re kept too.
	@concurrent static func imageRemoval(records: [DownloadedImageUsage], fileDates: [String: Date], urlsInUse: Set<String>, now: Date, limit: ByteLimit, hardLimit: ByteLimit) async -> ImageRemoval {
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
		var keys = Set(fileDates.filter { !recordedKeys.contains(baseDiskKey($0.key)) && $0.value < recentChangeDate }.keys)
		var byteCount = recordsToKeep.reduce(0) { $0 + $1.record.byteCount }

		func removeLeastRecentlyUsed(accessedBefore date: Date, limit: ByteLimit) {
			guard byteCount > limit.maximumByteCount else {
				return
			}
			for (record, key) in recordsToKeep {
				if byteCount <= limit.byteCountAfterRemoval || record.lastAccessed >= date {
					break
				}
				if keys.contains(key) || urlsInUse.contains(record.url) {
					continue
				}
				urls.append(record.url)
				keys.insert(key)
				byteCount -= record.byteCount
			}
		}
		removeLeastRecentlyUsed(accessedBefore: recentUseDate, limit: limit)
		removeLeastRecentlyUsed(accessedBefore: recentChangeDate, limit: hardLimit)

		// Derived copies go with their images.
		let removedKeys = keys.union(urls.map(diskKey))
		keys.formUnion(fileDates.keys.filter { baseDiskKey($0) != $0 && removedKeys.contains(baseDiskKey($0)) })

		return ImageRemoval(urls: urls, keys: keys, remainingByteCount: byteCount)
	}
}
