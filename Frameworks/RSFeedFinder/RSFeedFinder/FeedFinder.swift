//
//  FeedFinder.swift
//  RSFeedFinder
//
//  Created by Brent Simmons on 8/2/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSParser
import RSWeb
import RSCore

public protocol FeedFinderDelegate: class {

	func feedFinder(_: FeedFinder, didFindFeeds: Set<FeedSpecifier>)
}

public class FeedFinder {

	fileprivate weak var delegate: FeedFinderDelegate?
	fileprivate var feedSpecifiers = [String: FeedSpecifier]()
	fileprivate var didNotifyDelegate = false

	public var initialDownloadError: Error?
	public var initialDownloadStatusCode = -1

	public init(url: URL, delegate: FeedFinderDelegate) {

		self.delegate = delegate

		DispatchQueue.main.async() { () -> Void in

			self.findFeeds(url)
		}
	}

	deinit {
		notifyDelegateIfNeeded()
	}
}

private extension FeedFinder {

	func addFeedSpecifier(_ feedSpecifier: FeedSpecifier) {

		// If there’s an existing feed specifier, merge the two so that we have the best data. If one has a title and one doesn’t, use that non-nil title. Use the better source.

		if let existingFeedSpecifier = feedSpecifiers[feedSpecifier.urlString] {
			let mergedFeedSpecifier = existingFeedSpecifier.feedSpecifierByMerging(feedSpecifier)
			feedSpecifiers[feedSpecifier.urlString] = mergedFeedSpecifier
		}
		else {
			feedSpecifiers[feedSpecifier.urlString] = feedSpecifier
		}
	}

	func findFeedsInHTMLPage(htmlData: Data, urlString: String) {

		// Feeds in the <head> section we automatically assume are feeds.
		// If there are none from the <head> section,
		// then possible feeds in <body> section are downloaded individually
		// and added once we determine they are feeds.

		let possibleFeedSpecifiers = possibleFeedsInHTMLPage(htmlData: htmlData, urlString: urlString)
		var feedSpecifiersToDownload = Set<FeedSpecifier>()

		var didFindFeedInHTMLHead = false

		for oneFeedSpecifier in possibleFeedSpecifiers {
			if oneFeedSpecifier.source == .HTMLHead {
				addFeedSpecifier(oneFeedSpecifier)
				didFindFeedInHTMLHead = true
			}
			else {
				if !feedSpecifiersContainsURLString(oneFeedSpecifier.urlString) {
					feedSpecifiersToDownload.insert(oneFeedSpecifier)
				}
			}
		}

		if didFindFeedInHTMLHead || feedSpecifiersToDownload.isEmpty {
			stopFinding()
		}
		else {
			downloadFeedSpecifiers(feedSpecifiersToDownload)
		}
	}

	func possibleFeedsInHTMLPage(htmlData: Data, urlString: String) -> Set<FeedSpecifier> {

		let parserData = ParserData(url: urlString, data: htmlData)
		var feedSpecifiers = HTMLFeedFinder(parserData: parserData).feedSpecifiers

		if feedSpecifiers.isEmpty {
			// Odds are decent it’s a WordPress site, and just adding /feed/ will work.
			if let url = URL(string: urlString) {
				let feedURL = url.appendingPathComponent("feed", isDirectory: true)
				let wordpressFeedSpecifier = FeedSpecifier(title: nil, urlString: feedURL.absoluteString, source: .HTMLLink)
				feedSpecifiers.insert(wordpressFeedSpecifier)
			}
		}

		return feedSpecifiers
	}

	func feedSpecifiersContainsURLString(_ urlString: String) -> Bool {

		if let _ = feedSpecifiers[urlString] {
			return true
		}
		return false
	}

	func isHTML(_ data: Data) -> Bool {

		return (data as NSData).rs_dataIsProbablyHTML()
	}

	func findFeeds(_ initialURL: URL) {

		downloadInitialFeed(initialURL)
	}

	func downloadInitialFeed(_ initialURL: URL) {

		downloadUsingCache(initialURL) { (data, response, error) in

			self.initialDownloadStatusCode = response?.forcedStatusCode ?? -1

			if let error = error {
				self.initialDownloadError = error
				self.stopFinding()
				return
			}
			guard let data = data, let response = response else {
				self.stopFinding()
				return
			}

			if !response.statusIsOK || data.isEmpty {
				self.stopFinding()
				return
			}

			if self.isFeed(data, initialURL.absoluteString) {
				let feedSpecifier = FeedSpecifier(title: nil, urlString: initialURL.absoluteString, source: .UserEntered)
				self.addFeedSpecifier(feedSpecifier)
				self.stopFinding()
				return
			}

			if !self.isHTML(data) {
				self.stopFinding()
				return
			}

			self.findFeedsInHTMLPage(htmlData: data, urlString: initialURL.absoluteString)
		}
	}

	func downloadFeedSpecifiers(_ feedSpecifiers: Set<FeedSpecifier>) {

		var pendingDownloads = feedSpecifiers

		for oneFeedSpecifier in feedSpecifiers {

			guard let url = URL(string: oneFeedSpecifier.urlString) else {
				pendingDownloads.remove(oneFeedSpecifier)
				continue
			}

			downloadUsingCache(url) { (data, response, error) in

				pendingDownloads.remove(oneFeedSpecifier)

				if let data = data, let response = response, response.statusIsOK, error == nil {
					if self.isFeed(data, oneFeedSpecifier.urlString) {
						self.addFeedSpecifier(oneFeedSpecifier)
					}
				}

				if pendingDownloads.isEmpty {
					self.stopFinding()
				}
			}
		}
	}

	func stopFinding() {

		notifyDelegateIfNeeded()
	}

	func notifyDelegateIfNeeded() {

		if !didNotifyDelegate {
			delegate?.feedFinder(self, didFindFeeds: Set(feedSpecifiers.values))
			didNotifyDelegate = true
		}
	}

	func isFeed(_ data: Data, _ urlString: String) -> Bool {

		let parserData = ParserData(url: urlString, data: data)
		return FeedParser.canParse(parserData)
	}
}
