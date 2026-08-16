//
//  AccountOPMLLoadTests.swift
//  AccountTests
//
//  Created by Brent Simmons on 8/15/26.
//

import Testing
import RSParser
@testable import Account

@MainActor struct AccountOPMLLoadTests {

	private let accountManager = TestAccountManager()

	@Test func restoringOwnFileSetsNameOnly() throws {
		let account = accountManager.createAccount(type: .onMyMac)
		defer {
			accountManager.deleteAccount(account)
		}

		account.loadOPMLItems(try opmlItems(title: "Feed One"), isManualImport: false)

		let feed = try #require(account.flattenedFeeds().first)
		#expect(feed.name == "Feed One")
		#expect(feed.editedName == nil)
		#expect(feed.nameForDisplay == "Feed One")
	}

	@Test func importingSetsEditedNameSoTheTitleSurvivesRefreshes() throws {
		let account = accountManager.createAccount(type: .onMyMac)
		defer {
			accountManager.deleteAccount(account)
		}

		account.loadOPMLItems(try opmlItems(title: "My Name For It"), isManualImport: true)

		let feed = try #require(account.flattenedFeeds().first)
		#expect(feed.name == "My Name For It")
		#expect(feed.editedName == "My Name For It")
	}

	@Test func restoringOwnFileLeavesAnExistingEditedNameAlone() throws {
		let account = accountManager.createAccount(type: .onMyMac)
		defer {
			accountManager.deleteAccount(account)
		}

		// The user renamed this feed, so editedName is in the settings database already.
		account.loadOPMLItems(try opmlItems(title: "Feed One"), isManualImport: false)
		let renamedFeed = try #require(account.flattenedFeeds().first)
		renamedFeed.editedName = "My Name For It"

		// A later launch restores the file, which by then carries the edited name as its title.
		let specifier = try #require(try opmlItems(title: "My Name For It").first?.feedSpecifier)
		let restoredFeed = account.newFeed(with: specifier, isManualImport: false)

		#expect(restoredFeed.name == "My Name For It")
		#expect(restoredFeed.editedName == "My Name For It", "The rename lives in feed settings and should survive the restore.")
	}

	// MARK: - Helpers

	private func opmlItems(title: String) throws -> [OPMLItem] {
		let opml = """
		<?xml version="1.0" encoding="UTF-8"?>
		<opml version="1.1">
		<body>
		<outline text="\(title)" title="\(title)" type="rss" version="RSS" htmlUrl="https://example.com/" xmlUrl="https://example.com/feed.xml"/>
		</body>
		</opml>
		"""
		let data = try #require(opml.data(using: .utf8))
		let parserData = ParserData(url: "https://example.com/subscriptions.opml", data: data)
		let document = try OPMLParser.parseOPML(with: parserData)

		return try #require(document.children)
	}
}
