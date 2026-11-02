//
//  ImageDatabaseTests.swift
//  ImagesTests
//
//  Created by Brent Simmons on 10/27/26.
//

import Foundation
import Testing
import RSDatabase
import RSDatabaseObjC
import RSWeb
@testable import Images

@MainActor @Suite struct ImageDatabaseTests {

	@Test func legacyDatabaseIsImportedAndDeleted() async throws {
		let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ImageDatabaseTests-\(UUID().uuidString)")
		try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
		defer {
			try? FileManager.default.removeItem(at: folder)
		}
		let databasePath = folder.appendingPathComponent("Images.db").path
		let legacyDatabasePath = folder.appendingPathComponent("ImageMetadata.db").path
		writeLegacyDatabase(path: legacyDatabasePath)

		let imageDatabase = ImageDatabase(databasePath: databasePath, legacyDatabasePath: legacyDatabasePath)

		#expect(imageDatabase.faviconURL(forHomePageURL: "https://example.com/") == "https://example.com/favicon.ico")
		#expect(imageDatabase.iconURL(forFeedURL: "https://example.com/feed.xml") == "https://example.com/icon.png")
		#expect(imageDatabase.recentlyFailed(url: "https://example.com/missing.png"))
		#expect(!FileManager.default.fileExists(atPath: legacyDatabasePath))

		// Waits for the cleanup init queues, which would otherwise run after the folder is deleted.
		await imageDatabase.vacuum()
	}

	@Test func failedUsageQueryReturnsNil() {
		let database = FMDatabase.openAndSetUpDatabase(path: ":memory:")
		defer {
			database.close()
		}
		#expect(DownloadedImageTable.fetchUsageByLeastRecentAccess(database: database) == nil)
	}

	@Test func downloadedImagesAreSavedAndCheckedForThumbnailSuitability() async throws {
		let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ImageDatabaseTests-\(UUID().uuidString)")
		try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
		defer {
			try? FileManager.default.removeItem(at: folder)
		}
		let databasePath = folder.appendingPathComponent("Images.db").path
		let iconURL = "https://example.com/icon.png"
		let replacedIconURL = "https://example.com/replaced-icon.png"
		let photoURL = "https://example.com/photo.jpg"
		let unreadableImageURL = "https://example.com/unreadable.png"
		let nextCheck = Date(timeIntervalSince1970: 2_000_000_000)
		let conditionalGetInfo = try #require(HTTPConditionalGetInfo(lastModified: nil, etag: "\"abc\""))

		let imageDatabase = ImageDatabase(databasePath: databasePath)
		imageDatabase.saveDownloadedImage(DownloadedImageRecord(url: iconURL, pixelSize: (width: 48, height: 48), conditionalGetInfo: nil, nextCheck: nextCheck, isIcon: false))
		imageDatabase.saveDownloadedImage(DownloadedImageRecord(url: replacedIconURL, pixelSize: (width: 48, height: 48), conditionalGetInfo: nil, nextCheck: nextCheck, isIcon: false))
		imageDatabase.saveDownloadedImage(DownloadedImageRecord(url: replacedIconURL, pixelSize: (width: 512, height: 512), conditionalGetInfo: nil, nextCheck: nextCheck, isIcon: false))
		imageDatabase.saveDownloadedImage(DownloadedImageRecord(url: photoURL, pixelSize: (width: 800, height: 600), conditionalGetInfo: conditionalGetInfo, nextCheck: nextCheck, isIcon: false))
		imageDatabase.saveDownloadedImage(DownloadedImageRecord(url: unreadableImageURL, pixelSize: nil, conditionalGetInfo: nil, nextCheck: nextCheck, isIcon: false))

		let validation = await imageDatabase.fetchDownloadedImageValidation(url: photoURL)
		#expect(validation?.conditionalGetInfo == conditionalGetInfo)
		#expect(validation?.nextCheck == nextCheck)

		// Waits for the saves, so the database opened below sees them.
		await imageDatabase.vacuum()

		let reopenedImageDatabase = ImageDatabase(databasePath: databasePath)
		for database in [imageDatabase, reopenedImageDatabase] {
			#expect(database.isUnsuitableForThumbnail(url: iconURL))
			#expect(!database.isUnsuitableForThumbnail(url: replacedIconURL))
			#expect(!database.isUnsuitableForThumbnail(url: photoURL))
			#expect(database.isUnsuitableForThumbnail(url: unreadableImageURL))
		}

		// Waits for the cleanup init queues, which would otherwise run after the folder is deleted.
		await reopenedImageDatabase.vacuum()
	}
}

private extension ImageDatabaseTests {

	func writeLegacyDatabase(path: String) {
		let database = FMDatabase.openAndSetUpDatabase(path: path)
		let lastChecked = Date().timeIntervalSince1970
		database.executeStatements("""
		CREATE TABLE downloadFailure (url TEXT PRIMARY KEY NOT NULL, statusCode INTEGER, lastChecked REAL NOT NULL);
		CREATE TABLE homePageFavicon (homePageURL TEXT PRIMARY KEY NOT NULL, faviconURL TEXT, lastChecked REAL NOT NULL);
		CREATE TABLE feedIconURL (feedURL TEXT PRIMARY KEY NOT NULL, iconURL TEXT NOT NULL, lastChecked REAL NOT NULL);
		""")
		database.executeUpdate("INSERT INTO downloadFailure (url, statusCode, lastChecked) VALUES (?, ?, ?)", withArgumentsIn: ["https://example.com/missing.png", 404, lastChecked])
		database.executeUpdate("INSERT INTO homePageFavicon (homePageURL, faviconURL, lastChecked) VALUES (?, ?, ?)", withArgumentsIn: ["https://example.com/", "https://example.com/favicon.ico", lastChecked])
		database.executeUpdate("INSERT INTO feedIconURL (feedURL, iconURL, lastChecked) VALUES (?, ?, ?)", withArgumentsIn: ["https://example.com/feed.xml", "https://example.com/icon.png", lastChecked])
		database.close()
	}
}
