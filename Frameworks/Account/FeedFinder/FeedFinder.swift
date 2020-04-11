//
//  FeedFinder.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/2/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSParser
import RSWeb
import RSCore

class FeedFinder {
	
	static func find(url: URL, completion: @escaping (Result<Set<FeedSpecifier>, Error>) -> Void) {
		downloadAddingToCache(url) { (data, response, error) in
			if response?.forcedStatusCode == 404 {
				completion(.failure(AccountError.createErrorNotFound))
				return
			}
			
			if let error = error {
				completion(.failure(error))
				return
			}
			
			guard let data = data, let response = response else {
				completion(.failure(AccountError.createErrorNotFound))
				return
			}
			
			if !response.statusIsOK || data.isEmpty {
				completion(.failure(AccountError.createErrorNotFound))
				return
			}
			
			if FeedFinder.isFeed(data, url.absoluteString) {
				let feedSpecifier = FeedSpecifier(title: nil, urlString: url.absoluteString, source: .UserEntered)
				completion(.success(Set([feedSpecifier])))
				return
			}
			
			if !FeedFinder.isHTML(data) {
				completion(.failure(AccountError.createErrorNotFound))
				return
			}
			
			FeedFinder.findFeedsInHTMLPage(htmlData: data, urlString: url.absoluteString, completion: completion)
		}
	}
}

private extension FeedFinder {

	static func addFeedSpecifier(_ feedSpecifier: FeedSpecifier, feedSpecifiers: inout [String: FeedSpecifier]) {
		// If there’s an existing feed specifier, merge the two so that we have the best data. If one has a title and one doesn’t, use that non-nil title. Use the better source.

		if let existingFeedSpecifier = feedSpecifiers[feedSpecifier.urlString] {
			let mergedFeedSpecifier = existingFeedSpecifier.feedSpecifierByMerging(feedSpecifier)
			feedSpecifiers[feedSpecifier.urlString] = mergedFeedSpecifier
		}
		else {
			feedSpecifiers[feedSpecifier.urlString] = feedSpecifier
		}
	}

	static func findFeedsInHTMLPage(htmlData: Data, urlString: String, completion: @escaping (Result<Set<FeedSpecifier>, Error>) -> Void) {
		// Feeds in the <head> section we automatically assume are feeds.
		// If there are none from the <head> section,
		// then possible feeds in <body> section are downloaded individually
		// and added once we determine they are feeds.

		let possibleFeedSpecifiers = possibleFeedsInHTMLPage(htmlData: htmlData, urlString: urlString)
		var feedSpecifiers = [String: FeedSpecifier]()
		var feedSpecifiersToDownload = Set<FeedSpecifier>()

		var didFindFeedInHTMLHead = false

		for oneFeedSpecifier in possibleFeedSpecifiers {
			if oneFeedSpecifier.source == .HTMLHead {
				addFeedSpecifier(oneFeedSpecifier, feedSpecifiers: &feedSpecifiers)
				didFindFeedInHTMLHead = true
			}
			else {
				if feedSpecifiers[oneFeedSpecifier.urlString] == nil {
					feedSpecifiersToDownload.insert(oneFeedSpecifier)
				}
			}
		}

		if didFindFeedInHTMLHead {
			completion(.success(Set(feedSpecifiers.values)))
			return
		}
		else if feedSpecifiersToDownload.isEmpty {
			completion(.failure(AccountError.createErrorNotFound))
			return
		}
		else {
			downloadFeedSpecifiers(feedSpecifiersToDownload, feedSpecifiers: feedSpecifiers, completion: completion)
		}
	}

	static func possibleFeedsInHTMLPage(htmlData: Data, urlString: String) -> Set<FeedSpecifier> {
		let parserData = ParserData(url: urlString, data: htmlData)
		var feedSpecifiers = HTMLFeedFinder(parserData: parserData).feedSpecifiers

		if feedSpecifiers.isEmpty {
			// Odds are decent it’s a WordPress site, and just adding /feed/ will work.
			// It’s also fairly common for /index.xml to work.
			if let url = URL(string: urlString) {
				let feedURL = url.appendingPathComponent("feed", isDirectory: true)
				let wordpressFeedSpecifier = FeedSpecifier(title: nil, urlString: feedURL.absoluteString, source: .HTMLLink)
				feedSpecifiers.insert(wordpressFeedSpecifier)

				let indexXMLURL = url.appendingPathComponent("index.xml", isDirectory: false)
				let indexXMLFeedSpecifier = FeedSpecifier(title: nil, urlString: indexXMLURL.absoluteString, source: .HTMLLink)
				feedSpecifiers.insert(indexXMLFeedSpecifier)
			}
		}

		return feedSpecifiers
	}

	static func isHTML(_ data: Data) -> Bool {
		return data.isProbablyHTML
	}

	static func downloadFeedSpecifiers(_ downloadFeedSpecifiers: Set<FeedSpecifier>, feedSpecifiers: [String: FeedSpecifier], completion: @escaping (Result<Set<FeedSpecifier>, Error>) -> Void) {

		var resultFeedSpecifiers = feedSpecifiers
		let group = DispatchGroup()
		
		for downloadFeedSpecifier in downloadFeedSpecifiers {
			guard let url = URL(string: downloadFeedSpecifier.urlString) else {
				continue
			}
			
			group.enter()
			downloadUsingCache(url) { (data, response, error) in
				if let data = data, let response = response, response.statusIsOK, error == nil {
					if self.isFeed(data, downloadFeedSpecifier.urlString) {
						addFeedSpecifier(downloadFeedSpecifier, feedSpecifiers: &resultFeedSpecifiers)
					}
				}
				group.leave()
			}
			
		}

		group.notify(queue: DispatchQueue.main) {
			completion(.success(Set(resultFeedSpecifiers.values)))
		}
	}

	static func isFeed(_ data: Data, _ urlString: String) -> Bool {
		let parserData = ParserData(url: urlString, data: data)
		return FeedParser.canParse(parserData)
	}
}
