//
//  DownloadedImageCacheTests.swift
//  ImagesTests
//
//  Created by Brent Simmons on 10/26/26.
//

import Foundation
import Testing
import RSCore
@testable import Images

@Suite struct DownloadedImageCacheTests {

	@Test func leastRecentlyUsedImagesAreRemovedDownToLimit() async {
		let now = Date()
		let longAgo = now.addingTimeInterval(-TimeInterval(days: 10))
		let urls = ["https://example.com/a.jpg", "https://example.com/b.jpg", "https://example.com/c.jpg", "https://example.com/just-saved.jpg"]
		let records = [
			DownloadedImageUsage(url: "https://example.com/no-file.jpg", lastAccessed: longAgo, isIcon: false),
			DownloadedImageUsage(url: urls[0], lastAccessed: longAgo, isIcon: false),
			DownloadedImageUsage(url: urls[1], lastAccessed: longAgo, isIcon: false),
			DownloadedImageUsage(url: urls[2], lastAccessed: longAgo, isIcon: false),
			DownloadedImageUsage(url: urls[3], lastAccessed: now, isIcon: false)
		]
		let keys = urls.map { DownloadedImageCache.diskKey($0) }
		var files = Dictionary(uniqueKeysWithValues: keys.map { ($0, storedFile(longAgo, byteCount: 100)) })
		files["unrecorded"] = storedFile(longAgo, byteCount: 100)
		files["unrecordedJustSaved"] = storedFile(now, byteCount: 100)

		let removal = await DownloadedImageCache.imageRemoval(records: records, files: files, urlsInUse: [], now: now, maximumByteCount: 350)

		#expect(removal.urls == ["https://example.com/no-file.jpg", urls[0]])
		#expect(removal.keys == ["unrecorded", keys[0]])
		#expect(removal.remainingByteCount == 300)
	}

	@Test func imagesInUseAreKept() async {
		let now = Date()
		let longAgo = now.addingTimeInterval(-TimeInterval(days: 10))
		let records = (0..<3).map { DownloadedImageUsage(url: "https://example.com/\($0).jpg", lastAccessed: longAgo, isIcon: false) }
		let files = Dictionary(uniqueKeysWithValues: records.map { (DownloadedImageCache.diskKey($0.url), storedFile(longAgo, byteCount: 100)) })

		let removal = await DownloadedImageCache.imageRemoval(records: records, files: files, urlsInUse: [records[0].url], now: now, maximumByteCount: 200)

		#expect(removal.urls == [records[1].url])
		#expect(removal.remainingByteCount == 200)
	}

	@Test func derivedCopiesAreKeptAndRemovedWithTheirImages() async {
		let now = Date()
		let longAgo = now.addingTimeInterval(-TimeInterval(days: 10))
		let records = (0..<2).map { DownloadedImageUsage(url: "https://example.com/\($0).png", lastAccessed: longAgo.addingTimeInterval(TimeInterval($0)), isIcon: false) }
		let removedCopy = DownloadedImageCache.derivedDiskKey(records[0].url, suffix: "144")
		let keptCopy = DownloadedImageCache.derivedDiskKey(records[1].url, suffix: "144")
		let orphanedCopy = DownloadedImageCache.derivedDiskKey("https://example.com/gone.png", suffix: "144")
		var files = Dictionary(uniqueKeysWithValues: records.map { (DownloadedImageCache.diskKey($0.url), storedFile(longAgo, byteCount: 100)) })
		for key in [removedCopy, keptCopy, orphanedCopy] {
			files[key] = storedFile(longAgo, byteCount: 10)
		}

		let removal = await DownloadedImageCache.imageRemoval(records: records, files: files, urlsInUse: [], now: now, maximumByteCount: 150)

		#expect(removal.urls == [records[0].url])
		#expect(removal.keys == [DownloadedImageCache.diskKey(records[0].url), removedCopy, orphanedCopy])
		#expect(removal.remainingByteCount == 100)
	}

	@Test func iconsDoNotCountTowardLimit() async {
		let now = Date()
		let longAgo = now.addingTimeInterval(-TimeInterval(days: 10))
		let icon = DownloadedImageUsage(url: "https://example.com/apple-touch-icon.png", lastAccessed: longAgo, isIcon: true)
		let thumbnails = (0..<2).map { DownloadedImageUsage(url: "https://example.com/\($0).jpg", lastAccessed: longAgo.addingTimeInterval(TimeInterval($0 + 1)), isIcon: false) }
		let records = [icon] + thumbnails
		let files = Dictionary(uniqueKeysWithValues: records.map { (DownloadedImageCache.diskKey($0.url), storedFile(longAgo, byteCount: 100)) })

		let removal = await DownloadedImageCache.imageRemoval(records: records, files: files, urlsInUse: [], now: now, maximumByteCount: 100)

		#expect(removal.urls == [thumbnails[0].url])
		#expect(removal.remainingByteCount == 100)
	}

	@Test func iconsNotUsedIn180DaysAreRemoved() async {
		let now = Date()
		let unusedIcon = DownloadedImageUsage(url: "https://example.com/deleted-feed-icon.png", lastAccessed: now.addingTimeInterval(-TimeInterval(days: 181)), isIcon: true)
		let usedIcon = DownloadedImageUsage(url: "https://example.com/feed-icon.png", lastAccessed: now.addingTimeInterval(-TimeInterval(days: 179)), isIcon: true)
		let records = [unusedIcon, usedIcon]
		let files = Dictionary(uniqueKeysWithValues: records.map { (DownloadedImageCache.diskKey($0.url), storedFile(unusedIcon.lastAccessed, byteCount: 100)) })

		let removal = await DownloadedImageCache.imageRemoval(records: records, files: files, urlsInUse: [], now: now, maximumByteCount: 1000)

		#expect(removal.urls == [unusedIcon.url])
		#expect(removal.keys == [DownloadedImageCache.diskKey(unusedIcon.url)])
	}

	@Test func folderThatCantBeListedHasNoStoredFiles() async {
		let missingFolder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
		let files = await DownloadedImageCache.storedFiles(BinaryDiskCache(folder: missingFolder))
		#expect(files == nil)
	}

	@Test func storedFilesHaveTheirSizesOnDisk() async throws {
		let folder = FileManager.default.temporaryDirectory.appendingPathComponent("DownloadedImageCacheTests-\(UUID().uuidString)")
		try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
		defer {
			try? FileManager.default.removeItem(at: folder)
		}
		let diskCache = BinaryDiskCache(folder: folder.path)
		let key = DownloadedImageCache.diskKey("https://example.com/photo.jpg")
		try diskCache.setData(Data(count: 1234), forKey: key)

		let files = await DownloadedImageCache.storedFiles(diskCache)
		#expect(files?[key]?.byteCount == 1234)
	}

	@Test func shortMaxAgeIsRaisedToThreeDays() throws {
		let url = try #require(URL(string: "https://example.com/icon.png"))
		let httpResponse = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Cache-Control": "max-age=60", "ETag": "\"abc\""]))

		let interval = DownloadedImageCache.nextCheck(httpResponse, hasValidators: true).timeIntervalSinceNow
		#expect(interval > TimeInterval(days: 3) * 0.8 - 60 && interval < TimeInterval(days: 3) * 1.2)
	}

	@Test func imageWithoutValidatorsWaitsLongestBetweenChecks() throws {
		let url = try #require(URL(string: "https://example.com/icon.png"))
		let httpResponse = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Cache-Control": "max-age=60"]))

		let interval = DownloadedImageCache.nextCheck(httpResponse, hasValidators: false).timeIntervalSinceNow
		#expect(interval > TimeInterval(days: 30) * 0.8 - 60 && interval < TimeInterval(days: 30) * 1.2)
	}

	@Test func serverErrorsAndRateLimitsAreTransientButMissingImagesAreNot() {
		#expect(DownloadedImageCache.isTransient(statusCode: 503))
		#expect(DownloadedImageCache.isTransient(statusCode: 429))
		#expect(DownloadedImageCache.isTransient(statusCode: 408))
		#expect(!DownloadedImageCache.isTransient(statusCode: 404))
		#expect(!DownloadedImageCache.isTransient(statusCode: 403))
	}

	@Test func longerRetryAfterExtendsWaitAndLaterFailureDoesNotShortenIt() {
		let now = Date()
		let retryAfter = TimeInterval(days: 1)
		let firstRetryDate = DownloadedImageCache.retryDate(after: nil, retryAfter: nil, now: now)

		let retryDateFromRetryAfter = DownloadedImageCache.retryDate(after: firstRetryDate, retryAfter: retryAfter, now: now)
		#expect(retryDateFromRetryAfter == now.addingTimeInterval(retryAfter))

		let retryDateAfterLaterFailure = DownloadedImageCache.retryDate(after: retryDateFromRetryAfter, retryAfter: nil, now: now.addingTimeInterval(1))
		#expect(retryDateAfterLaterFailure == retryDateFromRetryAfter)
	}
}

private extension DownloadedImageCacheTests {

	func storedFile(_ modificationDate: Date, byteCount: Int) -> DownloadedImageCache.StoredFile {
		DownloadedImageCache.StoredFile(modificationDate: modificationDate, byteCount: byteCount)
	}
}
