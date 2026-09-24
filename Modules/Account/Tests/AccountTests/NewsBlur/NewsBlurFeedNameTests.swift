//
//  NewsBlurFeedNameTests.swift
//  AccountTests
//
//  Created by Brent Simmons on 8/15/26.
//

import Foundation
import Testing
import NewsBlur
@testable import Account

@MainActor struct NewsBlurFeedNameTests {

	private let accountManager = TestAccountManager()

	@Test func emptyNameKeepsExistingName() throws {
		let account = accountManager.createAccount(type: .newsBlur)
		defer {
			accountManager.deleteAccount(account)
		}
		let delegate = try #require(account.delegate as? NewsBlurAccountDelegate)

		try syncName("Feed One", delegate: delegate, account: account)
		try syncName("", delegate: delegate, account: account)

		#expect(account.existingFeed(withFeedID: "1")?.name == "Feed One")
	}

	@Test func serverRenameLeavesEditedNameAlone() throws {
		let account = accountManager.createAccount(type: .newsBlur)
		defer {
			accountManager.deleteAccount(account)
		}
		let delegate = try #require(account.delegate as? NewsBlurAccountDelegate)

		try syncName("Feed One", delegate: delegate, account: account)
		let feed = try #require(account.existingFeed(withFeedID: "1"))
		feed.editedName = "Edited Name"

		try syncName("Renamed On NewsBlur", delegate: delegate, account: account)

		#expect(feed.editedName == "Edited Name")
		#expect(feed.name == "Renamed On NewsBlur")
		#expect(feed.nameForDisplay == "Edited Name")
	}

	// MARK: - Helpers

	private func syncName(_ name: String, delegate: NewsBlurAccountDelegate, account: Account) throws {
		let feed = NewsBlurFeed(name: name, feedID: 1, feedURL: "https://example.com/feed.rss", homePageURL: "https://example.com/", faviconURL: nil)
		delegate.syncFeeds(account, [feed])
	}
}
