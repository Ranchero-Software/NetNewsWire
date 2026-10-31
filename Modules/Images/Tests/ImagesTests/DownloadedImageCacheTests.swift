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

	@Test func leastRecentlyUsedImagesAreRemovedDownToTarget() async {
		let now = Date()
		let longAgo = now.addingTimeInterval(-TimeInterval(days: 10))
		let urls = ["https://example.com/a.jpg", "https://example.com/b.jpg", "https://example.com/c.jpg", "https://example.com/just-saved.jpg"]
		let records = [
			DownloadedImageUsage(url: "https://example.com/no-file.jpg", byteCount: 50, lastAccessed: longAgo),
			DownloadedImageUsage(url: urls[0], byteCount: 100, lastAccessed: longAgo),
			DownloadedImageUsage(url: urls[1], byteCount: 100, lastAccessed: longAgo),
			DownloadedImageUsage(url: urls[2], byteCount: 100, lastAccessed: longAgo),
			DownloadedImageUsage(url: urls[3], byteCount: 100, lastAccessed: now)
		]
		let keys = urls.map { DownloadedImageCache.diskKey($0) }
		var fileDates = Dictionary(uniqueKeysWithValues: keys.map { ($0, longAgo) })
		fileDates["unrecorded"] = longAgo
		fileDates["unrecordedJustSaved"] = now

		let removal = await DownloadedImageCache.imageRemoval(records: records, fileDates: fileDates, urlsInUse: [], now: now, limit: .init(maximumByteCount: 350), hardLimit: .init(maximumByteCount: 1000))

		#expect(removal.urls == ["https://example.com/no-file.jpg", urls[0], urls[1]])
		#expect(removal.keys == ["unrecorded", keys[0], keys[1]])
		#expect(removal.remainingByteCount == 200)
	}

	@Test func imagesInUseAreKept() async {
		let now = Date()
		let longAgo = now.addingTimeInterval(-TimeInterval(days: 10))
		let records = (0..<3).map { DownloadedImageUsage(url: "https://example.com/\($0).jpg", byteCount: 100, lastAccessed: longAgo) }
		let fileDates = Dictionary(uniqueKeysWithValues: records.map { (DownloadedImageCache.diskKey($0.url), longAgo) })

		let removal = await DownloadedImageCache.imageRemoval(records: records, fileDates: fileDates, urlsInUse: [records[0].url], now: now, limit: .init(maximumByteCount: 200), hardLimit: .init(maximumByteCount: 1000))

		#expect(removal.urls == [records[1].url, records[2].url])
		#expect(removal.remainingByteCount == 100)
	}

	@Test func derivedCopiesAreKeptAndRemovedWithTheirImages() async {
		let now = Date()
		let longAgo = now.addingTimeInterval(-TimeInterval(days: 10))
		let records = (0..<2).map { DownloadedImageUsage(url: "https://example.com/\($0).png", byteCount: 100, lastAccessed: longAgo.addingTimeInterval(TimeInterval($0))) }
		let removedCopy = DownloadedImageCache.derivedDiskKey(records[0].url, suffix: "144")
		let keptCopy = DownloadedImageCache.derivedDiskKey(records[1].url, suffix: "144")
		let orphanedCopy = DownloadedImageCache.derivedDiskKey("https://example.com/gone.png", suffix: "144")
		var fileDates = Dictionary(uniqueKeysWithValues: records.map { (DownloadedImageCache.diskKey($0.url), longAgo) })
		for key in [removedCopy, keptCopy, orphanedCopy] {
			fileDates[key] = longAgo
		}

		let removal = await DownloadedImageCache.imageRemoval(records: records, fileDates: fileDates, urlsInUse: [], now: now, limit: .init(maximumByteCount: 150), hardLimit: .init(maximumByteCount: 1000))

		#expect(removal.urls == [records[0].url])
		#expect(removal.keys == [DownloadedImageCache.diskKey(records[0].url), removedCopy, orphanedCopy])
		#expect(removal.remainingByteCount == 100)
	}

	@Test func folderThatCantBeListedHasNoFileDates() async {
		let missingFolder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
		let fileDates = await DownloadedImageCache.fileModificationDates(BinaryDiskCache(folder: missingFolder))
		#expect(fileDates == nil)
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

	@Test func failureDuringWaitDoesNotDoubleIt() {
		let now = Date()
		let firstDelay = DownloadedImageCache.nextRetryDelay(after: nil, retryAfter: nil, now: now)

		let duringWait = DownloadedImageCache.nextRetryDelay(after: firstDelay, retryAfter: nil, now: now.addingTimeInterval(1))
		#expect(duringWait.delay == firstDelay.delay)
		#expect(duringWait.retryDate == firstDelay.retryDate)

		let longerRetryAfter = DownloadedImageCache.nextRetryDelay(after: firstDelay, retryAfter: firstDelay.delay * 10, now: now.addingTimeInterval(1))
		#expect(longerRetryAfter.retryDate == now.addingTimeInterval(1 + firstDelay.delay * 10))
		#expect(longerRetryAfter.isFromRetryAfter)
		#expect(!firstDelay.isFromRetryAfter)

		let afterWait = DownloadedImageCache.nextRetryDelay(after: firstDelay, retryAfter: nil, now: firstDelay.retryDate)
		#expect(afterWait.delay == firstDelay.delay * 2)
	}

	@Test func recentlyUsedImagesAreKeptUnlessOverHardLimit() async {
		let now = Date()
		let records = (0..<5).map { DownloadedImageUsage(url: "https://example.com/\($0).jpg", byteCount: 100, lastAccessed: now.addingTimeInterval(-TimeInterval(days: 1) + TimeInterval($0))) }
		let keys = records.map { DownloadedImageCache.diskKey($0.url) }
		let fileDates = Dictionary(uniqueKeysWithValues: keys.map { ($0, now.addingTimeInterval(-TimeInterval(days: 1))) })

		let underHardLimit = await DownloadedImageCache.imageRemoval(records: records, fileDates: fileDates, urlsInUse: [], now: now, limit: .init(maximumByteCount: 200), hardLimit: .init(maximumByteCount: 1000))
		#expect(underHardLimit.urls.isEmpty)
		#expect(underHardLimit.remainingByteCount == 500)

		let overHardLimit = await DownloadedImageCache.imageRemoval(records: records, fileDates: fileDates, urlsInUse: [], now: now, limit: .init(maximumByteCount: 200), hardLimit: .init(maximumByteCount: 400))
		#expect(overHardLimit.urls == [records[0].url, records[1].url])
		#expect(overHardLimit.remainingByteCount == 300)
	}
}
