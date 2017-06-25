//
//  RSParsedFeedTransformer.swift
//  RSParser
//
//  Created by Brent Simmons on 6/25/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// RSRSSParser and RSAtomParser were written in Objective-C quite a while ago.
// They create an RSParsedFeed object and related Objective-C objects.
// These functions take an RSParsedFeed and return a Swift-y ParsedFeed,
// which is part of providing a single API for feed parsing.

struct RSParsedFeedTransformer {

	static func parsedFeed(_ rsParsedFeed: RSParsedFeed) -> ParsedFeed {

		let items = parsedItems(rsParsedFeed.articles)
		return ParsedFeed(type: .rss, title: rsParsedFeed.title, homePageURL: rsParsedFeed.link, feedURL: rsParsedFeed.urlString, feedDescription: nil, nextURL: nil, iconURL: nil, faviconURL: nil, authors: nil, expired: false, hubs: nil, items: items)
	}
}

private extension RSParsedFeedTransformer {

	static func parsedItems(_ parsedArticles: Set<RSParsedArticle>) -> [ParsedItem] {

		// Create [ParsedItem] from set of RSParsedArticle.

		var items = [ParsedItem]()
		for oneParsedArticle in parsedArticles {
			items += [parsedItem(oneParsedArticle)]
		}
		return items
	}

	static func parsedItem(_ parsedArticle: RSParsedArticle) -> ParsedItem {

		let uniqueID = parsedArticle.articleID
		let url = parsedArticle.permalink
		let externalURL = parsedArticle.link
		let title = parsedArticle.title
		let contentHTML = parsedArticle.body
		let datePublished = parsedArticle.datePublished
		let dateModified = parsedArticle.dateModified
		let authors = parsedAuthors(parsedArticle.author)

		return ParsedItem(uniqueID: uniqueID, url: url, externalURL: externalURL, title: title, contentHTML: contentHTML, contentText: nil, summary: nil, imageURL: nil, bannerImageURL: nil, datePublished: datePublished, dateModified: dateModified, authors: authors, tags: nil, attachments: nil)
	}

	static func parsedAuthors(_ authorEmailAddress: String?) -> [ParsedAuthor]? {

		guard let authorEmailAddress = authorEmailAddress else {
			return nil
		}
		let author = ParsedAuthor(name: nil, url: nil, avatarURL: nil, emailAddress: authorEmailAddress)
		return [author]
	}
}
