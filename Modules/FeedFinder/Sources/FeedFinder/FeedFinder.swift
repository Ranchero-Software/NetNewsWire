//
//  FeedFinder.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/2/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSParser
import RSWeb
import RSCore

public enum FeedFinderError: LocalizedError {
	case feedNotFound

	public var errorDescription: String? {
		switch self {
		case .feedNotFound:
			return NSLocalizedString("The feed couldn’t be found and can’t be added.", comment: "Not found")
		}
	}
}

public final class FeedFinder {
	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "FeedFinder")

	@concurrent public static func find(url: URL) async throws -> Set<FeedSpecifier> {
		// Check special cases first.
		if let feedSpecifier = FeedSpecifier.knownFeedSpecifier(url: url) {
			logger.info("FeedFinder: found special case feed URL: \(url.absoluteString) - \(feedSpecifier.urlString)")
			return Set([feedSpecifier])
		}

		let (data, response) = try await Downloader.shared.download(url)

		if response?.forcedStatusCode == 404 {
			if var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false), urlComponents.host == "micro.blog" {
				urlComponents.path = "\(urlComponents.path).json"
				if let newURLString = urlComponents.url?.absoluteString {
					let microblogFeedSpecifier = FeedSpecifier(title: nil, urlString: newURLString, source: .HTMLLink, orderFound: 1)
					return Set([microblogFeedSpecifier])
				}
			}
			throw FeedFinderError.feedNotFound
		}

		guard let data, let response else {
			throw FeedFinderError.feedNotFound
		}

		if !response.statusIsOK || data.isEmpty {
			throw FeedFinderError.feedNotFound
		}

		if FeedFinder.isFeed(data, url.absoluteString) {
			let feedSpecifier = FeedSpecifier(title: nil, urlString: url.absoluteString, source: .userEntered, orderFound: 1)
			return Set([feedSpecifier])
		}

		if !FeedFinder.isHTML(data) {
			throw FeedFinderError.feedNotFound
		}

		return try await FeedFinder.findFeedsInHTMLPage(htmlData: data, urlString: url.absoluteString)
	}
}

private extension FeedFinder {

	static func addFeedSpecifier(_ feedSpecifier: FeedSpecifier, feedSpecifiers: inout [String: FeedSpecifier]) {
		// If there's an existing feed specifier, merge the two so that we have the best data. If one has a title and one doesn't, use that non-nil title. Use the better source.

		if let existingFeedSpecifier = feedSpecifiers[feedSpecifier.urlString] {
			let mergedFeedSpecifier = existingFeedSpecifier.feedSpecifierByMerging(feedSpecifier)
			feedSpecifiers[feedSpecifier.urlString] = mergedFeedSpecifier
		} else {
			feedSpecifiers[feedSpecifier.urlString] = feedSpecifier
		}
	}

	static func findFeedsInHTMLPage(htmlData: Data, urlString: String) async throws -> Set<FeedSpecifier> {
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
			} else {
				if feedSpecifiers[oneFeedSpecifier.urlString] == nil {
					feedSpecifiersToDownload.insert(oneFeedSpecifier)
				}
			}
		}

		if didFindFeedInHTMLHead {
			return Set(feedSpecifiers.values)
		} else if feedSpecifiersToDownload.isEmpty {
			throw FeedFinderError.feedNotFound
		} else {
			return await downloadFeedSpecifiers(feedSpecifiersToDownload, feedSpecifiers: feedSpecifiers)
		}
	}

	static func possibleFeedsInHTMLPage(htmlData: Data, urlString: String) -> Set<FeedSpecifier> {
		let parserData = ParserData(url: urlString, data: htmlData)
		var feedSpecifiers = HTMLFeedFinder(parserData: parserData).feedSpecifiers

		if feedSpecifiers.isEmpty {
			// Odds are decent it's a WordPress site, and just adding /feed/ will work.
			// It's also fairly common for /index.xml to work.
			if let url = URL(string: urlString) {
				let feedURL = url.appendingPathComponent("feed", isDirectory: true)
				let wordpressFeedSpecifier = FeedSpecifier(title: nil, urlString: feedURL.absoluteString, source: .HTMLLink, orderFound: 1)
				feedSpecifiers.insert(wordpressFeedSpecifier)

				let indexXMLURL = url.appendingPathComponent("index.xml", isDirectory: false)
				let indexXMLFeedSpecifier = FeedSpecifier(title: nil, urlString: indexXMLURL.absoluteString, source: .HTMLLink, orderFound: 1)
				feedSpecifiers.insert(indexXMLFeedSpecifier)
			}
		}

		return feedSpecifiers
	}

	static func isHTML(_ data: Data) -> Bool {
		return data.isProbablyHTML
	}

	static func downloadFeedSpecifiers(_ downloadFeedSpecifiers: Set<FeedSpecifier>, feedSpecifiers: [String: FeedSpecifier]) async -> Set<FeedSpecifier> {

		var resultFeedSpecifiers = feedSpecifiers

		await withTaskGroup(of: FeedSpecifier?.self) { group in
			for downloadFeedSpecifier in downloadFeedSpecifiers {
				guard let url = URL(string: downloadFeedSpecifier.urlString) else {
					continue
				}

				group.addTask {
					do {
						let (data, response) = try await Downloader.shared.download(url)
						if let data, let response, response.statusIsOK {
							if self.isFeed(data, downloadFeedSpecifier.urlString) {
								return downloadFeedSpecifier
							}
						}
					} catch {
						// Ignore download errors for individual feeds
					}
					return nil
				}
			}

			for await feedSpecifier in group {
				if let feedSpecifier {
					addFeedSpecifier(feedSpecifier, feedSpecifiers: &resultFeedSpecifiers)
				}
			}
		}

		return Set(resultFeedSpecifiers.values)
	}

	static func isFeed(_ data: Data, _ urlString: String) -> Bool {
		let parserData = ParserData(url: urlString, data: data)
		return FeedParser.canParse(parserData)
	}
}
