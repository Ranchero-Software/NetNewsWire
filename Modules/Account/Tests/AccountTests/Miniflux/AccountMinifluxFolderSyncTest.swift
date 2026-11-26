//
//  AccountMinifluxFolderSyncTest.swift
//  AccountTests
//
//  Created by Dave Marquard on 7/7/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Testing
import RSWeb
@testable import Account

@Suite(.isolatedWebserviceResponses) @MainActor struct AccountMinifluxFolderSyncTest {

	@Test func feedsLandInTheirCategoryFolders() async throws {
		setInitialSyncResponses()

		let account = TestAccountManager.shared.createAccount(type: .miniflux)
		defer {
			TestAccountManager.shared.deleteAccount(account)
		}
		account.endpointURL = URL(string: "https://miniflux.test")

		try await account.refreshAll()

		#expect(folderExternalIDsByName(account) == ["All": "1", "Tech": "2", "News": "3"])
		#expect(feedExternalIDsByFolderName(account) == ["All": ["101", "105"], "Tech": ["102", "103"], "News": ["104"]])
		#expect(account.topLevelFeeds.isEmpty)

		let generalFeed = try #require(account.existingFeed(withExternalID: "101"))
		#expect(generalFeed.url == "https://miniflux.test/feeds/general.xml")
		#expect(generalFeed.name == "General Feed")
	}

	@Test func removedAndAddedCategoriesUpdateFolders() async throws {
		setInitialSyncResponses()

		let account = TestAccountManager.shared.createAccount(type: .miniflux)
		defer {
			TestAccountManager.shared.deleteAccount(account)
		}
		account.endpointURL = URL(string: "https://miniflux.test")

		try await account.refreshAll()

		TestingURLProtocol.setResponse("/v1/categories", file: "JSON/miniflux_categories_delete.json")
		try await account.refreshAll()
		#expect(folderExternalIDsByName(account) == ["All": "1", "Tech": "2"])

		TestingURLProtocol.setResponse("/v1/categories", file: "JSON/miniflux_categories_add.json")
		try await account.refreshAll()
		#expect(folderExternalIDsByName(account) == ["All": "1", "Tech": "2", "News": "3", "Reviews": "4"])
	}
}

// MARK: - Helpers

private func setInitialSyncResponses() {
	TestingURLProtocol.setResponse("/v1/version", file: "JSON/miniflux_version.json")
	TestingURLProtocol.setResponse("/v1/categories", file: "JSON/miniflux_categories_initial.json")
	TestingURLProtocol.setResponse("/v1/feeds", file: "JSON/miniflux_feeds_initial.json")
	TestingURLProtocol.setResponse("/v1/entries/ids", file: "JSON/miniflux_entry_ids.json")
	TestingURLProtocol.setResponse("/v1/entries?", file: "JSON/miniflux_entries_page1.json")
}

@MainActor private func folderExternalIDsByName(_ account: Account) -> [String: String] {
	var externalIDsByName = [String: String]()
	for folder in account.folders ?? [] {
		externalIDsByName[folder.name ?? ""] = folder.externalID
	}
	return externalIDsByName
}

@MainActor private func feedExternalIDsByFolderName(_ account: Account) -> [String: Set<String>] {
	var externalIDsByName = [String: Set<String>]()
	for folder in account.folders ?? [] {
		externalIDsByName[folder.name ?? ""] = Set(folder.topLevelFeeds.map { $0.externalID ?? "" })
	}
	return externalIDsByName
}
