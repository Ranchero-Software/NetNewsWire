//
//  RSSFeedTransformer.swift
//  Parser
//
//  Created by Brent Simmons on 6/25/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct RSSFeedTransformer {

	/// Turn an internal RSSFeed into a public ParsedFeed.
	static func parsedFeed(with feed: RSSFeed, feedType: FeedType) -> ParsedFeed {

		let items = parsedItems(feed.articles)
		return ParsedFeed(type: feedType, title: feed.title, homePageURL: feed.link, feedURL: feed.urlString, language: feed.language, feedDescription: nil, nextURL: nil, iconURL: nil, faviconURL: nil, authors: nil, expired: false, hubs: nil, items: items)
	}
}

private extension RSSFeedTransformer {

	static func parsedItems(_ articles: [RSSArticle]?) -> Set<ParsedItem> {

		guard let articles else {
			return Set<ParsedItem>()
		}

		return Set(articles.map(parsedItem))
	}

	static func parsedItem(_ article: RSSArticle) -> ParsedItem {

		let uniqueID = article.articleID
		let url = article.permalink
		let externalURL = article.link
		let title = article.title
		let language = article.language
		let contentHTML = article.body
		let datePublished = article.datePublished
		let dateModified = article.dateModified
		let authors = parsedAuthors(article.authors)
		let attachments = parsedAttachments(article.enclosures)

		return ParsedItem(syncServiceID: nil, uniqueID: uniqueID, feedURL: article.feedURL, url: url, externalURL: externalURL, title: title, language: language, contentHTML: contentHTML, contentText: nil, summary: nil, imageURL: nil, bannerImageURL: nil, datePublished: datePublished, dateModified: dateModified, authors: authors, tags: nil, attachments: attachments)
	}

	static func parsedAuthors(_ authors: [RSSAuthor]?) -> Set<ParsedAuthor>? {

		guard let authors = authors, !authors.isEmpty else {
			return nil
		}

		let transformedAuthors = authors.compactMap { (author) -> ParsedAuthor? in
			return ParsedAuthor(name: author.name, url: author.url, avatarURL: nil, emailAddress: author.emailAddress)
		}

		return transformedAuthors.isEmpty ? nil : Set(transformedAuthors)
	}

	static func parsedAttachments(_ enclosures: [RSSEnclosure]?) -> Set<ParsedAttachment>? {

		guard let enclosures = enclosures, !enclosures.isEmpty else {
			return nil
		}

		let attachments = enclosures.compactMap { (enclosure) -> ParsedAttachment? in

			let sizeInBytes = (enclosure.length ?? 0) > 0 ? enclosure.length : nil
			return ParsedAttachment(url: enclosure.url, mimeType: enclosure.mimeType, title: nil, sizeInBytes: sizeInBytes, durationInSeconds: nil)
		}

		return attachments.isEmpty ? nil : Set(attachments)
	}
}
