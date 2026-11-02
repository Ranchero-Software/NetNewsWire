//
//  AppDefaultsMigrationTests.swift
//  NetNewsWire-iOSTests
//
//  Created by Brent Simmons on 10/22/26.
//

import Foundation
import Testing
@testable import NetNewsWire

@Suite struct AppDefaultsMigrationTests {

	// Test-only keys, since the host app has already registered defaults for the real keys.
	private static let paletteKey = "testMigrationUserInterfaceColorPalette"
	private static let lastRefreshKey = "testMigrationLastRefresh"

	@Test func migrateCopiesValuesWithoutOverwriting() throws {
		let sourceSuiteName = UUID().uuidString
		let destinationSuiteName = UUID().uuidString
		let source = try #require(UserDefaults(suiteName: sourceSuiteName))
		let destination = try #require(UserDefaults(suiteName: destinationSuiteName))
		defer {
			source.removePersistentDomain(forName: sourceSuiteName)
			destination.removePersistentDomain(forName: destinationSuiteName)
		}

		let oldRefreshDate = Date(timeIntervalSince1970: 1_700_000_000)
		let newRefreshDate = Date(timeIntervalSince1970: 1_800_000_000)
		source.set(2, forKey: Self.paletteKey)
		source.set(oldRefreshDate, forKey: Self.lastRefreshKey)
		destination.set(newRefreshDate, forKey: Self.lastRefreshKey)

		AppDefaults.migrate(from: source, to: destination, keys: [Self.paletteKey, Self.lastRefreshKey])

		#expect(destination.integer(forKey: Self.paletteKey) == 2)
		#expect(destination.object(forKey: Self.lastRefreshKey) as? Date == newRefreshDate)
	}
}
