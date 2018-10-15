//
//  FeedbinArticle.swift
//  Account
//
//  Created by Brent Simmons on 12/11/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSParser
import RSCore

struct FeedbinArticle {

	// https://github.com/feedbin/feedbin-api/blob/master/content/entries.md
	// https://github.com/feedbin/feedbin-api/blob/master/content/updated-entries.md
	//
	//	"id": 2077,
	//	"feed_id": 135,
	//	"title": "Objective-C Runtime Releases",
	//	"url": "http:\/\/mjtsai.com\/blog\/2013\/02\/02\/objective-c-runtime-releases\/",
	//	"author": "Michael Tsai",
	//	"content": "<p><a href=\"https:\/\/twitter.com\/bavarious\/status\/297851496945577984\">Bavarious<\/a> created a <a href=\"https:\/\/github.com\/bavarious\/objc4\/commits\/master\">GitHub repository<\/a> that shows the differences between versions of <a href=\"http:\/\/www.opensource.apple.com\/source\/objc4\/\">Apple\u2019s Objective-C runtime<\/a> that shipped with different versions of Mac OS X.<\/p>",
	//	"summary": "Bavarious created a GitHub repository that shows the differences between versions of Apple\u2019s Objective-C runtime that shipped with different versions of Mac OS X.",
	//	"published": "2013-02-03T01:00:19.000000Z",
	//	"created_at": "2013-02-04T01:00:19.127893Z"

	let articleID: Int
	let feedID: Int
	let title: String?
	let url: String?
	let authorName: String?
	let contentHTML: String?
	let contentDiffHTML: String?
	let summary: String?
	let datePublished: Date?
	let dateArrived: Date?

	struct Key {
		static let articleID = "id"
		static let feedID = "feed_id"
		static let title = "title"
		static let url = "url"
		static let authorName = "author"
		static let contentHTML = "content"
		static let contentDiffHTML = "content_diff"
		static let summary = "summary"
		static let datePublished = "published"
		static let dateArrived = "created_at"
	}

	init?(jsonDictionary: JSONDictionary) {
		guard let articleID = jsonDictionary[Key.articleID] as? Int else {
			return nil
		}
		guard let feedID = jsonDictionary[Key.feedID] as? Int else {
			return nil
		}
		self.articleID = articleID
		self.feedID = feedID

		self.title = jsonDictionary[Key.title] as? String
		self.url = jsonDictionary[Key.url] as? String
		self.authorName = jsonDictionary[Key.authorName] as? String

		if let contentHTML = jsonDictionary[Key.contentHTML] as? String, !contentHTML.isEmpty {
			self.contentHTML = contentHTML
		}
		else {
			self.contentHTML = nil
		}

		if let contentDiffHTML = jsonDictionary[Key.contentDiffHTML] as? String, !contentDiffHTML.isEmpty {
			self.contentDiffHTML = contentDiffHTML
		}
		else {
			self.contentDiffHTML = nil
		}
		
		if let summary = jsonDictionary[Key.summary] as? String, !summary.isEmpty {
			self.summary = summary
		}
		else {
			self.summary = nil
		}

		if let datePublishedString = jsonDictionary[Key.datePublished] as? String {
			self.datePublished = RSDateWithString(datePublishedString)
		}
		else {
			self.datePublished = nil
		}

		if let dateArrivedString = jsonDictionary[Key.dateArrived] as? String {
			self.dateArrived = RSDateWithString(dateArrivedString)
		}
		else {
			self.dateArrived = nil
		}
	}

	static func articles(with array: JSONArray) -> [FeedbinArticle]? {
		let articlesArray = array.compactMap { FeedbinArticle(jsonDictionary: $0) }
		return articlesArray.isEmpty ? nil : articlesArray
	}
}
