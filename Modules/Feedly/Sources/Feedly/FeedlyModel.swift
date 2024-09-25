//
//  FeedlyModel.swift
//
//
//  Created by Brent Simmons on 4/27/24.
//  Includes text of a bunch of files created by Kiel Gillard 2019-2020
//

import Foundation
import Articles
import Parser

public struct FeedlyCategory: Decodable, Sendable, Equatable {

	public let label: String
	public let id: String

	public static func ==(lhs: FeedlyCategory, rhs: FeedlyCategory) -> Bool {
		lhs.label == rhs.label && lhs.id == rhs.id
	}
}

public struct FeedlyCollection: Codable, Sendable, Hashable {

	public let feeds: [FeedlyFeed]
	public let label: String
	public let id: String

	public func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}

	public static func ==(lhs: FeedlyCollection, rhs: FeedlyCollection) -> Bool {
		lhs.id == rhs.id && lhs.label == rhs.label && lhs.feeds == rhs.feeds
	}
}

public struct FeedlyCollectionParser: Sendable {

	public let collection: FeedlyCollection

	private let rightToLeftTextSantizer = FeedlyRTLTextSanitizer()

	public var folderName: String {
		return rightToLeftTextSantizer.sanitize(collection.label) ?? ""
	}

	public var externalID: String {
		return collection.id
	}

	public init(collection: FeedlyCollection) {
		self.collection = collection
	}
}

public struct FeedlyEntry: Decodable, Sendable, Hashable {

	/// the unique, immutable ID for this particular article.
	public let id: String

	/// the article’s title. This string does not contain any HTML markup.
	public let title: String?

	public struct Content: Decodable, Sendable, Equatable {

		public enum Direction: String, Decodable, Sendable {
			case leftToRight = "ltr"
			case rightToLeft = "rtl"
		}

		public let content: String?
		public let direction: Direction?

		public static func ==(lhs: Content, rhs: Content) -> Bool {
			lhs.content == rhs.content && lhs.direction == rhs.direction
		}
	}

	/// This object typically has two values: “content” for the content itself, and “direction” (“ltr” for left-to-right, “rtl” for right-to-left). The content itself contains sanitized HTML markup.
	public let content: Content?

	/// content object the article summary. See the content object above.
	public let summary: Content?

	/// the author’s name
	public let author: String?

	///  the immutable timestamp, in ms, when this article was processed by the feedly Cloud servers.
	public let crawled: Date

	/// the timestamp, in ms, when this article was re-processed and updated by the feedly Cloud servers.
	public let recrawled: Date?

	/// the feed from which this article was crawled. If present, “streamId” will contain the feed id, “title” will contain the feed title, and “htmlUrl” will contain the feed’s website.
	public let origin: FeedlyOrigin?

	/// Used to help find the URL to visit an article on a web site.
	/// See https://groups.google.com/forum/#!searchin/feedly-cloud/feed$20url%7Csort:date/feedly-cloud/Rx3dVd4aTFQ/Hf1ZfLJoCQAJ
	public let canonical: [FeedlyLink]?

	/// a list of alternate links for this article. Each link object contains a media type and a URL. Typically, a single object is present, with a link to the original web page.
	public let alternate: [FeedlyLink]?

	/// Was this entry read by the user? If an Authorization header is not provided, this will always return false. If an Authorization header is provided, it will reflect if the user has read this entry or not.
	public let unread: Bool

	/// a list of tag objects (“id” and “label”) that the user added to this entry. This value is only returned if an Authorization header is provided, and at least one tag has been added. If the entry has been explicitly marked as read (not the feed itself), the “global.read” tag will be present.
	public let tags: [FeedlyTag]?

	/// a list of category objects (“id” and “label”) that the user associated with the feed of this entry. This value is only returned if an Authorization header is provided.
	public let categories: [FeedlyCategory]?

	/// A list of media links (videos, images, sound etc) provided by the feed. Some entries do not have a summary or content, only a collection of media links.
	public let enclosure: [FeedlyLink]?

	public func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}

	public static func ==(lhs: FeedlyEntry, rhs: FeedlyEntry) -> Bool {

		lhs.id == rhs.id && lhs.title == rhs.title && lhs.content == rhs.content && lhs.summary == rhs.summary && lhs.author == rhs.author && lhs.crawled == rhs.crawled && lhs.recrawled == rhs.recrawled && lhs.origin == rhs.origin && lhs.canonical == rhs.canonical && lhs.alternate == rhs.alternate && lhs.unread == rhs.unread && lhs.tags == rhs.tags && lhs.categories == rhs.categories && lhs.enclosure == rhs.enclosure
	}
}

public struct FeedlyEntryParser: Sendable {

	public let entry: FeedlyEntry

	private let rightToLeftTextSantizer = FeedlyRTLTextSanitizer()

	public var id: String {
		return entry.id
	}

	/// When ingesting articles, the feedURL must match a feed's `feedID` for the article to be reachable between it and its matching feed. It reminds me of a foreign key.
	public var feedUrl: String? {
		guard let id = entry.origin?.streamID else {
			// At this point, check Feedly's API isn't glitching or the response has not changed structure.
			assertionFailure("Entries need to be traceable to a feed or this entry will be dropped.")
			return nil
		}
		return id
	}

	/// Convoluted external URL logic "documented" here:
	/// https://groups.google.com/forum/#!searchin/feedly-cloud/feed$20url%7Csort:date/feedly-cloud/Rx3dVd4aTFQ/Hf1ZfLJoCQAJ
	public var externalUrl: String? {
		let multidimensionalArrayOfLinks = [entry.canonical, entry.alternate]
		let withExistingValues = multidimensionalArrayOfLinks.compactMap { $0 }
		let flattened = withExistingValues.flatMap { $0 }
		let webPageLinks = flattened.filter { $0.type == nil || $0.type == "text/html" }
		return webPageLinks.first?.href
	}

	public var title: String? {
		return rightToLeftTextSantizer.sanitize(entry.title)
	}

	public var contentHMTL: String? {
		return entry.content?.content ?? entry.summary?.content
	}

	public var contentText: String? {
		// We could strip HTML from contentHTML?
		return nil
	}

	public var summary: String? {
		return rightToLeftTextSantizer.sanitize(entry.summary?.content)
	}

	public var datePublished: Date {
		return entry.crawled
	}

	public var dateModified: Date? {
		return entry.recrawled
	}

	public var authors: Set<ParsedAuthor>? {
		guard let name = entry.author else {
			return nil
		}
		return Set([ParsedAuthor(name: name, url: nil, avatarURL: nil, emailAddress: nil)])
	}

	/// While there is not yet a tagging interface, articles can still be searched for by tags.
	public var tags: Set<String>? {
		guard let labels = entry.tags?.compactMap({ $0.label }), !labels.isEmpty else {
			return nil
		}
		return Set(labels)
	}

	public var attachments: Set<ParsedAttachment>? {
		guard let enclosure = entry.enclosure, !enclosure.isEmpty else {
			return nil
		}
		let attachments = enclosure.compactMap { ParsedAttachment(url: $0.href, mimeType: $0.type, title: nil, sizeInBytes: nil, durationInSeconds: nil) }
		return attachments.isEmpty ? nil : Set(attachments)
	}

	public var parsedItemRepresentation: ParsedItem? {
		guard let feedUrl = feedUrl else {
			return nil
		}

		return ParsedItem(syncServiceID: id,
						  uniqueID: id, // This value seems to get ignored or replaced.
						  feedURL: feedUrl,
						  url: nil,
						  externalURL: externalUrl,
						  title: title,
						  language: nil,
						  contentHTML: contentHMTL,
						  contentText: contentText,
						  summary: summary,
						  imageURL: nil,
						  bannerImageURL: nil,
						  datePublished: datePublished,
						  dateModified: dateModified,
						  authors: authors,
						  tags: tags,
						  attachments: attachments)
	}

	public init(entry: FeedlyEntry) {
		self.entry = entry
	}
}

public struct FeedlyFeed: Codable, Sendable, Equatable {

	public let id: String
	public let title: String?
	public let updated: Date?
	public let website: String?

	public static func ==(lhs: FeedlyFeed, rhs: FeedlyFeed) -> Bool {
		lhs.id == rhs.id && lhs.title == rhs.title && lhs.updated == rhs.updated && lhs.website == rhs.website
	}
}

public struct FeedlyFeedParser: Sendable {

	public let feed: FeedlyFeed

	private let rightToLeftTextSantizer = FeedlyRTLTextSanitizer()

	public var title: String? {
		return rightToLeftTextSantizer.sanitize(feed.title) ?? ""
	}

	public var feedID: String {
		return feed.id
	}

	public var url: String {
		let resource = FeedlyFeedResourceID(id: feed.id)
		return resource.url
	}

	public var homePageURL: String? {
		return feed.website
	}

	public init(feed: FeedlyFeed) {

		self.feed = feed
	}
}

public struct FeedlyFeedsSearchResponse: Decodable, Sendable {

	public struct Feed: Decodable, Sendable {

		public let title: String
		public let feedID: String
	}

	public let results: [Feed]
}

public struct FeedlyLink: Decodable, Sendable, Equatable {

	public let href: String

	/// The mime type of the resource located by `href`.
	/// When `nil`, it's probably a web page?
	/// https://groups.google.com/forum/#!searchin/feedly-cloud/feed$20url%7Csort:date/feedly-cloud/Rx3dVd4aTFQ/Hf1ZfLJoCQAJ
	public let type: String?

	public static func ==(lhs: FeedlyLink, rhs: FeedlyLink) -> Bool {
		lhs.href == rhs.href && lhs.type == rhs.type
	}
}

public struct FeedlyOrigin: Decodable, Sendable, Equatable {

	public let title: String?
	public let streamID: String?
	public let htmlURL: String?

	public static func ==(lhs: FeedlyOrigin, rhs: FeedlyOrigin) -> Bool {

		lhs.title == rhs.title && lhs.streamID == rhs.streamID && lhs.htmlURL == rhs.htmlURL
	}
}

/// The kinds of Resource IDs is documented here: https://developer.feedly.com/cloud/
public protocol FeedlyResourceID {

	/// The resource ID from Feedly.
	@MainActor var id: String { get }
}

/// The Feed Resource is documented here: https://developer.feedly.com/cloud/
public struct FeedlyFeedResourceID: FeedlyResourceID, Sendable {

	public let id: String

	/// The location of the kind of resource a concrete type represents.
	/// If the concrete type cannot strip the resource type from the ID, it should just return the ID
	/// since the ID is a legitimate URL.
	/// This is basically assuming Feedly prefixes source feed URLs with `feed/`.
	/// It is not documented as such and could potentially change.
	/// Feedly does not include the source feed URL as a separate field.
	/// See https://developer.feedly.com/v3/feeds/#get-the-metadata-about-a-specific-feed
	public var url: String {
		if let range = id.range(of: "feed/"), range.lowerBound == id.startIndex {
			var mutant = id
			mutant.removeSubrange(range)
			return mutant
		}

		// It seems values like "something/https://my.blog/posts.xml" is a legit URL.
		return id
	}

	public init(id: String) {
		self.id = id
	}
}

extension FeedlyFeedResourceID {

	init(url: String) {
		self.id = "feed/\(url)"
	}
}

public struct FeedlyCategoryResourceID: FeedlyResourceID, Sendable {

	public let id: String

	public enum Global {

		public static func uncategorized(for userID: String) -> FeedlyCategoryResourceID {
			// https://developer.feedly.com/cloud/#global-resource-ids
			let id = "user/\(userID)/category/global.uncategorized"
			return FeedlyCategoryResourceID(id: id)
		}

		/// All articles from all the feeds the user subscribes to.
		public static func all(for userID: String) -> FeedlyCategoryResourceID {
			// https://developer.feedly.com/cloud/#global-resource-ids
			let id = "user/\(userID)/category/global.all"
			return FeedlyCategoryResourceID(id: id)
		}

		/// All articles from all the feeds the user loves most.
		public static func mustRead(for userID: String) -> FeedlyCategoryResourceID {
			// https://developer.feedly.com/cloud/#global-resource-ids
			let id = "user/\(userID)/category/global.must"
			return FeedlyCategoryResourceID(id: id)
		}
	}
}

public struct FeedlyTagResourceID: FeedlyResourceID, Sendable {

	public let id: String

	public enum Global {

		public static func saved(for userID: String) -> FeedlyTagResourceID {
			// https://developer.feedly.com/cloud/#global-resource-ids
			let id = "user/\(userID)/tag/global.saved"
			return FeedlyTagResourceID(id: id)
		}
	}
}

public struct FeedlyRTLTextSanitizer: Sendable {

	private let rightToLeftPrefix = "<div style=\"direction:rtl;text-align:right\">"
	private let rightToLeftSuffix = "</div>"

	public func sanitize(_ sourceText: String?) -> String? {
		guard let source = sourceText, !source.isEmpty else {
			return sourceText
		}

		guard source.hasPrefix(rightToLeftPrefix) && source.hasSuffix(rightToLeftSuffix) else {
			return source
		}

		let start = source.index(source.startIndex, offsetBy: rightToLeftPrefix.indices.count)
		let end = source.index(source.endIndex, offsetBy: -rightToLeftSuffix.indices.count)
		return String(source[start..<end])
	}
}

public struct FeedlyStream: Decodable, Sendable {

	public let id: String

	/// Of the most recent entry for this stream (regardless of continuation, newerThan, etc).
	public let updated: Date?

	/// the continuation id to pass to the next stream call, for pagination.
	/// This id guarantees that no entry will be duplicated in a stream (meaning, there is no need to de-duplicate entries returned by this call).
	/// If this value is not returned, it means the end of the stream has been reached.
	public let continuation: String?
	public let items: [FeedlyEntry]

	public var isStreamEnd: Bool {
		return continuation == nil
	}
}

public struct FeedlyStreamIDs: Decodable, Sendable {

	public let continuation: String?
	public let ids: [String]

	public var isStreamEnd: Bool {
		return continuation == nil
	}
}

public struct FeedlyTag: Decodable, Sendable, Equatable {

	public let id: String
	public let label: String?

	public static func ==(lhs: FeedlyTag, rhs: FeedlyTag) -> Bool {
		lhs.id == rhs.id && lhs.label == rhs.label
	}
}

public enum FeedlyMarkAction: String, Sendable {

	case read
	case unread
	case saved
	case unsaved

	/// These values are paired with the "action" key in POST requests to the markers API.
	/// See for example: https://developer.feedly.com/v3/markers/#mark-one-or-multiple-articles-as-read
	public var actionValue: String {
		switch self {
		case .read:
			return "markAsRead"
		case .unread:
			return "keepUnread"
		case .saved:
			return "markAsSaved"
		case .unsaved:
			return "markAsUnsaved"
		}
	}
}
