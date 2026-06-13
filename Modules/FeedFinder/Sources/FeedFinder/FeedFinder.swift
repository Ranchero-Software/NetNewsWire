//
//  FeedFinder.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/2/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os
import RSParser
import RSWeb
import RSCore
import ActivityLog

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

	/// Which discovery path produced the result. Used to write a more useful
	/// completion message on the parent `findFeed` activity.
	enum FindStrategy {
		case specialCase
		case microblogJSON
		case directFeed
		case htmlHead
		case candidates
	}

	@concurrent public static func find(url: URL) async throws -> Set<FeedSpecifier> {
		let activityID = await activityStart(url: url)
		do {
			let (result, strategy) = try await performFind(url: url)
			await activityComplete(id: activityID, result: result, strategy: strategy)
			return result
		} catch {
			await activityFail(id: activityID, error: error)
			throw error
		}
	}

	@concurrent private static func performFind(url: URL) async throws -> (Set<FeedSpecifier>, FindStrategy) {
		// Check special cases first.
		if let feedSpecifier = FeedSpecifier.knownFeedSpecifier(url: url) {
			logger.info("FeedFinder: found special case feed URL: \(url.absoluteString) - \(feedSpecifier.urlString)")
			return (Set([feedSpecifier]), .specialCase)
		}

		let (data, response) = try await downloadAndLog(url)

		if response?.forcedStatusCode == 404 {
			if var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false), urlComponents.host == "micro.blog" {
				urlComponents.path = "\(urlComponents.path).json"
				if let newURLString = urlComponents.url?.absoluteString {
					let microblogFeedSpecifier = FeedSpecifier(title: nil, urlString: newURLString, source: .HTMLLink, orderFound: 1)
					return (Set([microblogFeedSpecifier]), .microblogJSON)
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
			return (Set([feedSpecifier]), .directFeed)
		}

		if !FeedFinder.isHTML(data) {
			throw FeedFinderError.feedNotFound
		}

		return try await FeedFinder.findFeedsInHTMLPage(htmlData: data, urlString: url.absoluteString)
	}

	/// Wraps `Downloader.shared.download(url)` with a per-URL activity entry so
	/// the activity log shows every URL that was tried and what came back.
	/// HTTP non-2xx is recorded as a *completed* activity (the network call
	/// worked, the server returned a status); a thrown error (network failure,
	/// timeout, DNS) records as `failed`.
	///
	/// Public so callers performing feed-finding-adjacent fetches (e.g. the
	/// post-find download that validates the chosen feed) can have their
	/// fetches appear in the same Feed Finder activity stream.
	public static func downloadAndLog(_ url: URL) async throws -> (Data?, URLResponse?) {
		let id = await activityFetchStart(url: url)
		do {
			let (data, response) = try await Downloader.shared.download(url)
			await activityFetchComplete(id: id, data: data, response: response)
			return (data, response)
		} catch {
			await activityFetchFail(id: id, error: error)
			throw error
		}
	}

	@MainActor private static func activityStart(url: URL) -> Int {
		let activityLog = ActivityLog.shared
		let id = activityLog.createActivity(owner: .feedFinder, kind: .findFeed(urlString: url.absoluteString))
		activityLog.didStart(id: id)
		return id
	}

	@MainActor private static func activityComplete(id: Int, result: Set<FeedSpecifier>, strategy: FindStrategy) {
		let message = parentCompletionMessage(result: result, strategy: strategy)
		ActivityLog.shared.didComplete(id: id, message: message)
	}

	@MainActor private static func activityFail(id: Int, error: any Error) {
		ActivityLog.shared.didFail(id: id, error: error)
	}

	@MainActor private static func activityFetchStart(url: URL) -> Int {
		let activityLog = ActivityLog.shared
		let id = activityLog.createActivity(owner: .feedFinder, kind: .fetchFeedCandidate(urlString: url.absoluteString))
		activityLog.didStart(id: id)
		return id
	}

	@MainActor private static func activityFetchComplete(id: Int, data: Data?, response: URLResponse?) {
		let message = fetchCompletionMessage(data: data, response: response)
		// A cached fetch can complete in zero seconds; suppress the misleading "(0.00s)".
		ActivityLog.shared.didComplete(id: id, message: message, durationIsSignificant: false)
	}

	@MainActor private static func activityFetchFail(id: Int, error: any Error) {
		ActivityLog.shared.didFail(id: id, error: error)
	}
}

extension FeedFinder {

	/// True when `feedURLString` is on the same host as `pageURLString` and its
	/// path equals or is nested under the page's path. The page must have a
	/// non-root path — a root request (e.g. example.com/) gets no on-path
	/// preference, preserving the existing <head>-feed behavior for whole sites.
	static func feedURLString(_ feedURLString: String, isUnderRequestedPageURLString pageURLString: String) -> Bool {
		guard let feedURL = URL(string: feedURLString), let pageURL = URL(string: pageURLString),
			let feedHost = feedURL.host(), let pageHost = pageURL.host() else {
			return false
		}
		func normalizedHost(_ host: String) -> String {
			let lowered = host.lowercased(with: localeForLowercasing)
			return lowered.hasPrefix("www.") ? String(lowered.dropFirst("www.".count)) : lowered
		}
		guard normalizedHost(feedHost) == normalizedHost(pageHost) else {
			return false
		}
		let pagePath = pageURL.path.hasSuffix("/") ? String(pageURL.path.dropLast()) : pageURL.path
		guard pagePath.count > 1 else {
			return false
		}
		return feedURL.path == pagePath || feedURL.path.hasPrefix(pagePath + "/")
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

	static func findFeedsInHTMLPage(htmlData: Data, urlString: String) async throws -> (Set<FeedSpecifier>, FindStrategy) {
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

		// A body-linked feed whose URL lives *under* the requested page's path
		// (e.g. /blog/feed for a /blog request) is more specific than a
		// site-wide feed declared in <head> (e.g. a network master feed). Prefer
		// it: validate the on-path body candidates and, if any are real feeds,
		// return those instead of the <head> feed. Without this, any <head> feed
		// unconditionally suppressed every body feed, so a page-specific feed was
		// discarded before it could be considered. (#5299)
		let onPathToDownload = feedSpecifiersToDownload.filter {
			Self.feedURLString($0.urlString, isUnderRequestedPageURLString: urlString)
		}
		if !onPathToDownload.isEmpty {
			let onPathFeeds = await downloadFeedSpecifiers(onPathToDownload, feedSpecifiers: [:])
			if !onPathFeeds.isEmpty {
				return (onPathFeeds, .candidates)
			}
		}

		if didFindFeedInHTMLHead {
			return (Set(feedSpecifiers.values), .htmlHead)
		} else if feedSpecifiersToDownload.isEmpty {
			throw FeedFinderError.feedNotFound
		} else {
			let result = await downloadFeedSpecifiers(feedSpecifiersToDownload, feedSpecifiers: feedSpecifiers)
			return (result, .candidates)
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
						let (data, response) = try await downloadAndLog(url)
						if let data, let response, response.statusIsOK {
							if self.isFeed(data, downloadFeedSpecifier.urlString) {
								return downloadFeedSpecifier
							}
						}
					} catch {
						// The per-URL activity has already recorded the failure;
						// one bad candidate shouldn't fail the whole find.
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

	static func parentCompletionMessage(result: Set<FeedSpecifier>, strategy: FindStrategy) -> String {
		let count = result.count
		if count == 0 {
			switch strategy {
			case .candidates:
				return "No feeds found in candidate URLs"
			default:
				return "No feeds found"
			}
		}
		let plural = count == 1 ? "feed" : "feeds"
		switch strategy {
		case .specialCase:
			return "\(count) \(plural) (special case match)"
		case .microblogJSON:
			return "\(count) \(plural) via Micro.blog .json fallback"
		case .directFeed:
			return "Direct feed"
		case .htmlHead:
			return "\(count) \(plural) via HTML <head>"
		case .candidates:
			return "\(count) \(plural) via candidate URLs"
		}
	}

	static func fetchCompletionMessage(data: Data?, response: URLResponse?) -> String {
		guard let response else {
			return "No response"
		}
		let statusPart = formattedStatus(response.forcedStatusCode)
		if response.statusIsOK, let data, !data.isEmpty {
			let sizeText = Int64(data.count).formatted(.byteCount(style: .file))
			return "\(statusPart) · \(sizeText)"
		}
		return statusPart
	}

	static func formattedStatus(_ statusCode: Int) -> String {
		if statusCode == 0 {
			return "No status"
		}
		// HTTPURLResponse.localizedString returns lowercase phrases like "not found".
		// 200 maps to "no error" in some Foundation builds; spell out "OK" ourselves.
		let phrase: String
		switch statusCode {
		case 200:
			phrase = "OK"
		case 304:
			phrase = "Not Modified"
		default:
			phrase = HTTPURLResponse.localizedString(forStatusCode: statusCode).capitalized
		}
		return "\(statusCode) \(phrase)"
	}
}
