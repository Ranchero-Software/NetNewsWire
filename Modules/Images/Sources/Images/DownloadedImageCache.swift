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

/// Downloads each image URL once and keeps one copy on disk, shared by every `ImageDownloader`.
///
/// The copy is scaled down to `maxPixelSize`, the largest size anything displays,
/// or kept as is when it’s already smaller. Each `ImageDownloader` makes its own size from it.
/// Requests for a URL that’s already being read or downloaded share that work.
@MainActor final class DownloadedImageCache {

	static let shared = DownloadedImageCache()

	/// The size of large thumbnails, the largest images displayed.
	nonisolated static let maxPixelSize = 1200

	private static let folderName = "DownloadedImages"
	nonisolated private static let compressionQuality = 0.8
	private static let maximumConcurrentLimitedDownloads = 4

	nonisolated private static let logger = Logger(subsystem: Logger.nnwSubsystem, category: "DownloadedImageCache")

	private let diskCache: BinaryDiskCache
	private let downloadLimiter = DownloadLimiter(maximumConcurrentDownloads: maximumConcurrentLimitedDownloads)
	private var tasks = [String: Task<Result<Data, ImageDownloadError>, Never>]() // url: task

	private init() {
		let folder = AppConfig.cacheSubfolder(named: Self.folderName)
		self.diskCache = BinaryDiskCache(folder: folder.path)
	}

	/// The stored copy, read from disk or downloaded. Downloads that use the download limiter
	/// wait their turn, and don’t start when offline or in Low Data Mode.
	/// Activity log fires only when the request reaches the network.
	func imageData(for url: String, usesDownloadLimiter: Bool, activityOwner: ActivityOwner?, activityKind: ActivityKind?, activityDetail: String?) async throws(ImageDownloadError) -> Data {
		if let task = tasks[url] {
			return try await task.value.get()
		}

		let task = Task {
			await findImage(url, usesDownloadLimiter: usesDownloadLimiter, activityOwner: activityOwner, activityKind: activityKind, activityDetail: activityDetail)
		}
		tasks[url] = task
		let result = await task.value
		tasks[url] = nil
		return try result.get()
	}
}

private extension DownloadedImageCache {

	func findImage(_ url: String, usesDownloadLimiter: Bool, activityOwner: ActivityOwner?, activityKind: ActivityKind?, activityDetail: String?) async -> Result<Data, ImageDownloadError> {
		if let data = await Self.readFromDisk(diskCache, key: Self.diskKey(url)) {
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

		let statusCode = (downloadResponse.response as? HTTPURLResponse)?.statusCode
		if let data = downloadResponse.data, !data.isEmpty, let response = downloadResponse.response, response.statusIsOK {
			let storedData = await Self.scaledImageData(data)
			await Self.saveToDisk(diskCache, key: Self.diskKey(url), data: storedData)
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

	static func diskKey(_ url: String) -> String {
		url.md5String
	}

	/// Data that ImageIO can’t read, such as SVG, is kept as is, since `RSImage` may still read it.
	@concurrent static func scaledImageData(_ data: Data) async -> Data {
		RSImage.scaledImageData(data, maxPixelSize: maxPixelSize, format: .jpeg(compressionQuality: compressionQuality)) ?? data
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
}
