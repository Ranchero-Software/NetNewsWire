//
//  ArticleImageDownloader.swift
//  Images
//
//  Caches images embedded in article HTML so articles can be viewed offline.
//
//  Unlike ImageDownloader (which downscales to icon size), this keeps the
//  original image bytes, since these are displayed full-size in the article view.
//

import Foundation
import os
import RSCore
import RSWeb

@MainActor public final class ArticleImageDownloader {

	public static let shared = ArticleImageDownloader()

	nonisolated static private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ArticleImageDownloader")

	nonisolated private let diskCache: BinaryDiskCache
	nonisolated private let queue: DispatchQueue

	/// On-disk footprint of the article-image cache.
	public struct CacheStats: Sendable {
		public let fileCount: Int
		public let byteCount: Int64
	}

	// Full-size article images are large, so the in-memory cache is bounded by total byte
	// cost (NSCache auto-evicts under memory pressure on both platforms — unlike a plain
	// dictionary, which only the notifications below would ever clear).
	private let imageCache: NSCache<NSString, NSData> = {
		let cache = NSCache<NSString, NSData>()
		cache.totalCostLimit = 50_000_000 // ~50 MB
		return cache
	}()
	private var inFlight = [String: Task<Data?, Never>]() // coalesces concurrent downloads of the same url

	// Prefetch is fire-and-forget over a whole refresh's worth of images, so cap how many
	// download at once instead of enqueueing an unbounded burst of background fetches.
	private static let maxConcurrentPrefetches = 4
	private var activePrefetchCount = 0
	private var pendingPrefetchURLs = [String]()
	private var queuedPrefetchURLs = Set<String>() // dedupes the pending queue

	/// Re-checked before draining the prefetch queue so that turning the offline-caching
	/// setting off mid-refresh stops queued downloads. Injected by the app layer, which owns
	/// the setting (this module can't see AppDefaults). Defaults to always-enabled.
	public var isPrefetchingEnabled: @MainActor () -> Bool = { true }

	// Article images come from arbitrary feed-supplied URLs, so bound what we're willing to
	// write to disk: skip implausibly large responses and anything that isn't actually an image.
	private static let maxImageByteCount = 20_000_000 // 20 MB

	// Total on-disk cap for the offline image cache. Since the ArticleImages folder is kept out
	// of the routine cache flush while offline caching is on, it needs its own bound; oldest
	// images are evicted once the total exceeds this.
	nonisolated private static let maxDiskCacheByteCount: Int64 = 500_000_000 // 500 MB
	// Run eviction once per this many bytes written rather than on every file, so the coalesced
	// check covers all write paths (render-time and prefetch) without enumerating on each save.
	nonisolated private static let evictionCheckByteInterval: Int64 = 50_000_000 // 50 MB
	// Only ever mutated on `queue` (serial), so unsynchronized access is safe.
	nonisolated(unsafe) private var bytesWrittenSinceEviction: Int64 = 0

	init() {
		let folder = AppConfig.cacheSubfolder(named: "ArticleImages")
		self.diskCache = BinaryDiskCache(folder: folder.path)
		self.queue = DispatchQueue(label: "ArticleImageDownloader serial queue - \(folder.path)")

		NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidGoToBackground(_:)), name: .appDidGoToBackground, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleLowMemory(_:)), name: .lowMemory, object: nil)

		enforceDiskCacheLimit() // reclaim anything over the cap left by a previous session
	}

	@objc func handleAppDidGoToBackground(_ notification: Notification) {
		imageCache.removeAllObjects()
	}

	@objc func handleLowMemory(_ notification: Notification) {
		imageCache.removeAllObjects()
	}

	/// Ensure the image at `url` is cached on disk. Fire-and-forget; used at article-download time.
	/// Downloads are throttled to `maxConcurrentPrefetches` at a time.
	public func prefetch(_ url: String) {
		guard isHTTP(url), cachedData(url) == nil, !queuedPrefetchURLs.contains(url) else {
			return
		}
		queuedPrefetchURLs.insert(url)
		pendingPrefetchURLs.append(url)
		startPendingPrefetchesIfPossible()
	}

	/// Total on-disk footprint of the article-image cache (file count and bytes).
	/// Enumerates the cache folder off the main thread on the disk queue.
	nonisolated public func cacheStats() async -> CacheStats {
		await withCheckedContinuation { continuation in
			queue.async {
				continuation.resume(returning: Self.computeCacheStats(folderPath: self.diskCache.folder))
			}
		}
	}

	/// Evict the oldest cached images (by file date) until the on-disk cache is back under its
	/// size cap. Runs on the disk queue. Call after a batch of caching (prefetch drain / cache-all).
	nonisolated public func enforceDiskCacheLimit() {
		queue.async {
			Self.evictIfOverLimit(folderPath: self.diskCache.folder, maxBytes: Self.maxDiskCacheByteCount)
		}
	}

	/// Return image bytes from memory, then disk, then (if allowed) the network.
	/// Returns nil if the image isn't cached and can't be fetched.
	public func data(for url: String, allowNetwork: Bool) async -> Data? {
		guard isHTTP(url) else {
			return nil
		}
		if let data = cachedData(url) {
			return data
		}
		if let data = await readFromDisk(url) {
			setCachedData(data, url)
			return data
		}
		guard allowNetwork else {
			return nil
		}
		return await download(url)
	}
}

private extension ArticleImageDownloader {

	func isHTTP(_ url: String) -> Bool {
		let lowercased = url.lowercased()
		return lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://")
	}

	/// Start pending prefetch downloads up to the concurrency limit, freeing a slot (and
	/// pulling the next URL) as each finishes.
	func startPendingPrefetchesIfPossible() {
		guard isPrefetchingEnabled() else {
			pendingPrefetchURLs.removeAll()
			queuedPrefetchURLs.removeAll()
			return
		}
		while activePrefetchCount < Self.maxConcurrentPrefetches, !pendingPrefetchURLs.isEmpty {
			let url = pendingPrefetchURLs.removeFirst()
			queuedPrefetchURLs.remove(url)
			activePrefetchCount += 1
			Task { @MainActor in
				// Re-check in case the setting was turned off after this slot was dequeued but
				// before it started (in-flight downloads already past this point still finish).
				if isPrefetchingEnabled(), await readFromDisk(url) == nil {
					_ = await download(url)
				}
				activePrefetchCount -= 1
				if activePrefetchCount == 0, pendingPrefetchURLs.isEmpty {
					enforceDiskCacheLimit() // keep the cache under its cap once a burst finishes
				}
				startPendingPrefetchesIfPossible()
			}
		}
	}

	/// Download, save to disk, cache in memory, and return the bytes. Returns nil on failure.
	/// Concurrent calls for the same url share a single download (so a background prefetch
	/// and a foreground display request don't race or duplicate work).
	func download(_ url: String) async -> Data? {
		if let existing = inFlight[url] {
			return await existing.value
		}
		if ImageMetadataDatabase.shared.recentlyFailed(url: url) {
			Self.logger.debug("Skipping recently-failed URL: \(url)")
			return nil
		}
		let task = Task { @MainActor in
			await performDownload(url)
		}
		inFlight[url] = task
		let result = await task.value
		inFlight[url] = nil
		return result
	}

	func performDownload(_ url: String) async -> Data? {
		guard let imageURL = URL(string: url) else {
			ImageMetadataDatabase.shared.recordFailure(url: url, statusCode: nil)
			return nil
		}

		let downloadResponse: DownloadResponse
		do {
			downloadResponse = try await Downloader.shared.download(imageURL)
		} catch {
			Self.logger.error("Error downloading article image at \(url): \(error.localizedDescription)")
			return nil // transient — don't record a failure
		}
		let data = downloadResponse.data
		let response = downloadResponse.response

		if let response, response.statusIsOK {
			// Only cache a plausible image response. An empty body (a transient CDN hiccup), an
			// oversized body, or a non-image body is treated as transient: return nil without
			// blacklisting, so a later view can retry. Don't permanently fail on OK statuses.
			guard let data, !data.isEmpty, data.count <= Self.maxImageByteCount, isProbablyImage(data, response: response) else {
				return nil
			}
			saveToDisk(url, data)
			setCachedData(data, url)
			ImageMetadataDatabase.shared.clearFailure(url: url)
			return data
		}

		let statusCode = (response as? HTTPURLResponse)?.statusCode
		let isTransient = statusCode.map { (500...599).contains($0) } ?? true
		if !isTransient {
			ImageMetadataDatabase.shared.recordFailure(url: url, statusCode: statusCode)
		}
		return nil
	}

	/// Whether a response looks like an image worth caching: an image/* Content-Type, or
	/// failing that, recognizable image magic bytes. Keeps non-image bodies (error pages,
	/// redirects to HTML, etc.) fetched from feed-supplied URLs out of the disk cache.
	func isProbablyImage(_ data: Data, response: URLResponse) -> Bool {
		if let mimeType = response.mimeType?.lowercased(), mimeType.hasPrefix("image/") {
			return true
		}
		return Self.hasImageMagicBytes(data)
	}

	nonisolated static func hasImageMagicBytes(_ data: Data) -> Bool {
		let bytes = [UInt8](data.prefix(12))
		guard bytes.count >= 3 else {
			return false
		}
		if bytes[0] == 0xFF, bytes[1] == 0xD8, bytes[2] == 0xFF {
			return true // JPEG
		}
		if bytes.count >= 8, bytes[0] == 0x89, bytes[1] == 0x50, bytes[2] == 0x4E, bytes[3] == 0x47 {
			return true // PNG
		}
		if bytes[0] == 0x47, bytes[1] == 0x49, bytes[2] == 0x46 {
			return true // GIF
		}
		if bytes[0] == 0x42, bytes[1] == 0x4D {
			return true // BMP
		}
		if bytes[0] == 0x49, bytes[1] == 0x49, bytes[2] == 0x2A {
			return true // TIFF (little-endian)
		}
		if bytes[0] == 0x4D, bytes[1] == 0x4D, bytes[2] == 0x00 {
			return true // TIFF (big-endian)
		}
		if bytes.count >= 12, bytes[0] == 0x52, bytes[1] == 0x49, bytes[2] == 0x46, bytes[3] == 0x46,
			bytes[8] == 0x57, bytes[9] == 0x45, bytes[10] == 0x42, bytes[11] == 0x50 {
			return true // WebP (RIFF....WEBP)
		}
		if bytes.count >= 12, bytes[4] == 0x66, bytes[5] == 0x74, bytes[6] == 0x79, bytes[7] == 0x70 {
			let brand = String(bytes: bytes[8..<12], encoding: .ascii) ?? ""
			// ISO base media (ftyp) — accept only image brands, not video (mp4 etc.)
			if brand.hasPrefix("avif") || brand.hasPrefix("avis") || brand.hasPrefix("heic") || brand.hasPrefix("heix") || brand.hasPrefix("mif1") || brand.hasPrefix("msf1") {
				return true // AVIF / HEIC
			}
		}
		if bytes.count >= 4, bytes[0] == 0x00, bytes[1] == 0x00, bytes[2] == 0x01, bytes[3] == 0x00 {
			return true // ICO
		}
		return false
	}

	func cachedData(_ url: String) -> Data? {
		imageCache.object(forKey: url as NSString) as Data?
	}

	func setCachedData(_ data: Data, _ url: String) {
		imageCache.setObject(data as NSData, forKey: url as NSString, cost: data.count)
	}

	func saveToDisk(_ url: String, _ data: Data) {
		queue.async {
			self.diskCache[self.diskKey(url)] = data
			// Every cached image — prefetch or render-time (the scheme handler's data(for:) path) —
			// is written here, so enforce the size cap from the write path too, coalesced to once
			// per evictionCheckByteInterval to avoid enumerating the folder on every save.
			self.bytesWrittenSinceEviction += Int64(data.count)
			if self.bytesWrittenSinceEviction >= Self.evictionCheckByteInterval {
				self.bytesWrittenSinceEviction = 0
				Self.evictIfOverLimit(folderPath: self.diskCache.folder, maxBytes: Self.maxDiskCacheByteCount)
			}
		}
	}

	func readFromDisk(_ url: String) async -> Data? {
		await withCheckedContinuation { continuation in
			queue.async {
				let data = self.diskCache[self.diskKey(url)]
				DispatchQueue.main.async {
					continuation.resume(returning: (data?.isEmpty == false) ? data : nil)
				}
			}
		}
	}

	nonisolated func diskKey(_ url: String) -> String {
		url.md5String
	}

	nonisolated static func evictIfOverLimit(folderPath: String, maxBytes: Int64) {
		let folderURL = URL(fileURLWithPath: folderPath)
		let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
		let fileManager = FileManager.default
		guard let enumerator = fileManager.enumerator(at: folderURL, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
			return
		}
		var files = [(url: URL, size: Int64, date: Date)]()
		var total: Int64 = 0
		for case let fileURL as URL in enumerator {
			guard let values = try? fileURL.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else {
				continue
			}
			let size = Int64(values.fileSize ?? 0)
			files.append((fileURL, size, values.contentModificationDate ?? .distantPast))
			total += size
		}
		guard total > maxBytes else {
			return
		}
		// Evict oldest-cached first until back under the cap.
		files.sort { $0.date < $1.date }
		for file in files {
			if total <= maxBytes {
				break
			}
			do {
				try fileManager.removeItem(at: file.url)
				total -= file.size
			} catch {
				logger.error("ArticleImageDownloader: could not evict \(file.url.lastPathComponent): \(error.localizedDescription)")
			}
		}
	}

	nonisolated static func computeCacheStats(folderPath: String) -> CacheStats {
		let folderURL = URL(fileURLWithPath: folderPath)
		let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
		guard let enumerator = FileManager.default.enumerator(at: folderURL, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
			return CacheStats(fileCount: 0, byteCount: 0)
		}
		var fileCount = 0
		var byteCount: Int64 = 0
		for case let fileURL as URL in enumerator {
			guard let values = try? fileURL.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else {
				continue
			}
			fileCount += 1
			byteCount += Int64(values.fileSize ?? 0)
		}
		return CacheStats(fileCount: fileCount, byteCount: byteCount)
	}
}
