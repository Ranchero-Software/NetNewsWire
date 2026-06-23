//
//  AuthorCacheTests.swift
//  ArticlesTests
//
//  Created by Brent Simmons on 4/28/26.
//

import Foundation
import Testing

@testable import Articles

@Suite struct AuthorCacheTests {

	@Test func addReturnsExistingValueOnSecondCall() throws {
		let cache = AuthorCache()
		let original = try #require(makeAuthor(name: "Jane", url: "https://example.com/jane"))
		let copy = try #require(makeAuthor(name: "Jane", url: "https://example.com/jane"))
		#expect(original.authorID == copy.authorID)

		_ = cache.add([original])
		_ = cache.add([copy])
		#expect(cache.count() == 1)
	}

	@Test func addSetReturnsCanonicalSet() throws {
		let cache = AuthorCache()
		let jane = try #require(makeAuthor(name: "Jane"))
		let john = try #require(makeAuthor(name: "John"))
		let result = cache.add([jane, john])
		#expect(result.count == 2)
		#expect(cache.count() == 2)
	}

	@Test func clearEmptiesCache() throws {
		let cache = AuthorCache()
		let jane = try #require(makeAuthor(name: "Jane"))
		_ = cache.add([jane])
		#expect(cache.count() == 1)
		cache.clear()
		#expect(cache.count() == 0)
	}

	@Test func distinctAuthorsCoexist() throws {
		let cache = AuthorCache()
		let jane = try #require(makeAuthor(name: "Jane"))
		let john = try #require(makeAuthor(name: "John"))
		#expect(jane.authorID != john.authorID)
		_ = cache.add([jane, john])
		#expect(cache.count() == 2)
	}
}

@Suite(.serialized) struct AuthorCacheSharedTests {

	init() {
		AuthorCache.shared.clear()
	}

	@Test func roundTripThroughAuthorsWithJSON() throws {
		let jane = try #require(makeAuthor(name: "Jane", url: "https://example.com/jane"))
		let authors: Set<Author> = [jane]
		let json = try #require(authors.json())
		let data = try #require(json.data(using: .utf8))

		_ = Author.authorsWithJSON(data)
		_ = Author.authorsWithJSON(data)
		#expect(AuthorCache.shared.count() == 1)
	}
}

private func makeAuthor(name: String? = nil, url: String? = nil, avatarURL: String? = nil,
                        emailAddress: String? = nil) -> Author? {
	Author(authorID: nil, name: name, url: url, avatarURL: avatarURL, emailAddress: emailAddress)
}
