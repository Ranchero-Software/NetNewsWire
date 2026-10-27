//
//  DownloadedImageCacheTests.swift
//  ImagesTests
//
//  Created by Brent Simmons on 10/26/26.
//

import Foundation
import Testing
@testable import Images

@Suite struct DownloadedImageCacheTests {

	@Test func leastRecentlyUsedImagesAreRemovedDownToTarget() {
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
		fileDates["unrecorded-just-saved"] = now

		let removal = DownloadedImageCache.imageRemoval(records: records, fileDates: fileDates, now: now, limit: .init(maximumByteCount: 350), hardLimit: .init(maximumByteCount: 1000))

		#expect(removal.urls == ["https://example.com/no-file.jpg", urls[0], urls[1]])
		#expect(removal.keys == ["unrecorded", keys[0], keys[1]])
		#expect(removal.remainingByteCount == 200)
	}

	@Test func shortMaxAgeIsRaisedToThreeDays() throws {
		let url = try #require(URL(string: "https://example.com/icon.png"))
		let httpResponse = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Cache-Control": "max-age=60", "ETag": "\"abc\""]))

		let interval = DownloadedImageCache.nextCheck(httpResponse, hasValidators: true).timeIntervalSinceNow
		#expect(abs(interval - TimeInterval(days: 3)) < 60)
	}

	@Test func recentlyUsedImagesAreKeptUnlessOverHardLimit() {
		let now = Date()
		let records = (0..<5).map { DownloadedImageUsage(url: "https://example.com/\($0).jpg", byteCount: 100, lastAccessed: now.addingTimeInterval(-TimeInterval(days: 1) + TimeInterval($0))) }
		let keys = records.map { DownloadedImageCache.diskKey($0.url) }
		let fileDates = Dictionary(uniqueKeysWithValues: keys.map { ($0, now.addingTimeInterval(-TimeInterval(days: 1))) })

		let underHardLimit = DownloadedImageCache.imageRemoval(records: records, fileDates: fileDates, now: now, limit: .init(maximumByteCount: 200), hardLimit: .init(maximumByteCount: 1000))
		#expect(underHardLimit.urls.isEmpty)
		#expect(underHardLimit.remainingByteCount == 500)

		let overHardLimit = DownloadedImageCache.imageRemoval(records: records, fileDates: fileDates, now: now, limit: .init(maximumByteCount: 200), hardLimit: .init(maximumByteCount: 400))
		#expect(overHardLimit.urls == [records[0].url, records[1].url])
		#expect(overHardLimit.remainingByteCount == 300)
	}
}
