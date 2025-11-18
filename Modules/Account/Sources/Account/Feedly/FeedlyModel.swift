//
//  File.swift
//  Account
//
//  Created by Brent Simmons on 11/17/25.
//

import Foundation
import RSParser

struct FeedlyCategory: Decodable, Sendable {
	let label: String
	let id: String
}

struct FeedlyCollection: Codable, Sendable {
	let feeds: [FeedlyFeed]
	let label: String
	let id: String
}

struct FeedlyCollectionParser {
	let collection: FeedlyCollection

	private let rightToLeftTextSantizer = FeedlyRTLTextSanitizer()

	var folderName: String {
		return rightToLeftTextSantizer.sanitize(collection.label) ?? ""
	}

	var externalID: String {
		return collection.id
	}
}

struct FeedlyFeed: Codable, Sendable {
	let id: String
	let title: String?
	let updated: Date?
	let website: String?
}

struct FeedlyFeedParser {
	let feed: FeedlyFeed

	private let rightToLeftTextSantizer = FeedlyRTLTextSanitizer()

	var title: String? {
		return rightToLeftTextSantizer.sanitize(feed.title) ?? ""
	}

	var feedID: String {
		return feed.id
	}

	var url: String {
		let resource = FeedlyFeedResourceId(id: feed.id)
		return resource.url
	}

	var homePageURL: String? {
		return feed.website
	}
}

struct FeedlyFeedsSearchResponse: Decodable, Sendable {
	struct Feed: Decodable {
		let title: String
		let feedId: String
	}

	let results: [Feed]
}

struct FeedlyLink: Decodable, Sendable {
	let href: String

	/// The mime type of the resource located by `href`.
	/// When `nil`, it's probably a web page?
	/// https://groups.google.com/forum/#!searchin/feedly-cloud/feed$20url%7Csort:date/feedly-cloud/Rx3dVd4aTFQ/Hf1ZfLJoCQAJ
	let type: String?
}

struct FeedlyOrigin: Decodable, Sendable {
	let title: String?
	let streamId: String?
	let htmlUrl: String?
}

struct FeedlyStream: Decodable, Sendable {
	let id: String

	/// Of the most recent entry for this stream (regardless of continuation, newerThan, etc).
	let updated: Date?

	/// the continuation id to pass to the next stream call, for pagination.
	/// This id guarantees that no entry will be duplicated in a stream (meaning, there is no need to de-duplicate entries returned by this call).
	/// If this value is not returned, it means the end of the stream has been reached.
	let continuation: String?
	let items: [FeedlyEntry]

	var isStreamEnd: Bool {
		return continuation == nil
	}
}

struct FeedlyStreamIds: Decodable, Sendable {
	let continuation: String?
	let ids: [String]

	var isStreamEnd: Bool {
		return continuation == nil
	}
}

struct FeedlyTag: Decodable, Sendable {
	let id: String
	let label: String?
}

struct FeedlyEntry: Decodable, Sendable {
	/// the unique, immutable ID for this particular article.
	let id: String

	/// the article’s title. This string does not contain any HTML markup.
	let title: String?

	struct Content: Decodable {

		enum Direction: String, Decodable {
			case leftToRight = "ltr"
			case rightToLeft = "rtl"
		}

		let content: String?
		let direction: Direction?
	}

	/// This object typically has two values: “content” for the content itself, and “direction” (“ltr” for left-to-right, “rtl” for right-to-left). The content itself contains sanitized HTML markup.
	let content: Content?

	/// content object the article summary. See the content object above.
	let summary: Content?

	/// the author’s name
	let author: String?

	///  the immutable timestamp, in ms, when this article was processed by the feedly Cloud servers.
	let crawled: Date

	/// the timestamp, in ms, when this article was re-processed and updated by the feedly Cloud servers.
	let recrawled: Date?

	/// the feed from which this article was crawled. If present, “streamId” will contain the feed id, “title” will contain the feed title, and “htmlUrl” will contain the feed’s website.
	let origin: FeedlyOrigin?

	/// Used to help find the URL to visit an article on a web site.
	/// See https://groups.google.com/forum/#!searchin/feedly-cloud/feed$20url%7Csort:date/feedly-cloud/Rx3dVd4aTFQ/Hf1ZfLJoCQAJ
	let canonical: [FeedlyLink]?

	/// a list of alternate links for this article. Each link object contains a media type and a URL. Typically, a single object is present, with a link to the original web page.
	let alternate: [FeedlyLink]?

	/// Was this entry read by the user? If an Authorization header is not provided, this will always return false. If an Authorization header is provided, it will reflect if the user has read this entry or not.
	let unread: Bool

	/// a list of tag objects (“id” and “label”) that the user added to this entry. This value is only returned if an Authorization header is provided, and at least one tag has been added. If the entry has been explicitly marked as read (not the feed itself), the “global.read” tag will be present.
	let tags: [FeedlyTag]?

	/// a list of category objects (“id” and “label”) that the user associated with the feed of this entry. This value is only returned if an Authorization header is provided.
	let categories: [FeedlyCategory]?

	/// A list of media links (videos, images, sound etc) provided by the feed. Some entries do not have a summary or content, only a collection of media links.
	let enclosure: [FeedlyLink]?
}

struct FeedlyEntryParser {
	let entry: FeedlyEntry

	private let rightToLeftTextSantizer = FeedlyRTLTextSanitizer()

	var id: String {
		return entry.id
	}

	/// When ingesting articles, the feedURL must match a feed's `feedID` for the article to be reachable between it and its matching feed. It reminds me of a foreign key.
	var feedUrl: String? {
		guard let id = entry.origin?.streamId else {
			// At this point, check Feedly's API isn't glitching or the response has not changed structure.
			assertionFailure("Entries need to be traceable to a feed or this entry will be dropped.")
			return nil
		}
		return id
	}

	/// Convoluted external URL logic "documented" here:
	/// https://groups.google.com/forum/#!searchin/feedly-cloud/feed$20url%7Csort:date/feedly-cloud/Rx3dVd4aTFQ/Hf1ZfLJoCQAJ
	var externalUrl: String? {
		let multidimensionalArrayOfLinks = [entry.canonical, entry.alternate]
		let withExistingValues = multidimensionalArrayOfLinks.compactMap { $0 }
		let flattened = withExistingValues.flatMap { $0 }
		let webPageLinks = flattened.filter { $0.type == nil || $0.type == "text/html" }
		return webPageLinks.first?.href
	}

	var title: String? {
		return rightToLeftTextSantizer.sanitize(entry.title)
	}

	var contentHMTL: String? {
		return entry.content?.content ?? entry.summary?.content
	}

	var contentText: String? {
		// We could strip HTML from contentHTML?
		return nil
	}

	var summary: String? {
		return rightToLeftTextSantizer.sanitize(entry.summary?.content)
	}

	var datePublished: Date {
		return entry.crawled
	}

	var dateModified: Date? {
		return entry.recrawled
	}

	var authors: Set<ParsedAuthor>? {
		guard let name = entry.author else {
			return nil
		}
		return Set([ParsedAuthor(name: name, url: nil, avatarURL: nil, emailAddress: nil)])
	}

	/// While there is not yet a tagging interface, articles can still be searched for by tags.
	var tags: Set<String>? {
		guard let labels = entry.tags?.compactMap({ $0.label }), !labels.isEmpty else {
			return nil
		}
		return Set(labels)
	}

	var attachments: Set<ParsedAttachment>? {
		guard let enclosure = entry.enclosure, !enclosure.isEmpty else {
			return nil
		}
		let attachments = enclosure.compactMap { ParsedAttachment(url: $0.href, mimeType: $0.type, title: nil, sizeInBytes: nil, durationInSeconds: nil) }
		return attachments.isEmpty ? nil : Set(attachments)
	}

	var parsedItemRepresentation: ParsedItem? {
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
						  markdown: nil,
						  summary: summary,
						  imageURL: nil,
						  bannerImageURL: nil,
						  datePublished: datePublished,
						  dateModified: dateModified,
						  authors: authors,
						  tags: tags,
						  attachments: attachments)
	}
}

struct FeedlyRTLTextSanitizer: Sendable {
	private let rightToLeftPrefix = "<div style=\"direction:rtl;text-align:right\">"
	private let rightToLeftSuffix = "</div>"

	func sanitize(_ sourceText: String?) -> String? {
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

protocol FeedlyEntryIdentifierProviding: AnyObject {
	var entryIDs: Set<String> { get }
}

final class FeedlyEntryIdentifierProvider: FeedlyEntryIdentifierProviding {
	private(set) var entryIDs: Set<String>

	init(entryIDs: Set<String> = Set()) {
		self.entryIDs = entryIDs
	}

	func addEntryIDs(from provider: FeedlyEntryIdentifierProviding) {
		entryIDs.formUnion(provider.entryIDs)
	}

	func addEntryIDs(in articleIDs: [String]) {
		entryIDs.formUnion(articleIDs)
	}
}

/// The kinds of Resource Ids is documented here: https://developer.feedly.com/cloud/
protocol FeedlyResourceId {

	/// The resource Id from Feedly.
	var id: String { get }
}

/// The Feed Resource is documented here: https://developer.feedly.com/cloud/
struct FeedlyFeedResourceId: FeedlyResourceId {
	let id: String

	/// The location of the kind of resource a concrete type represents.
	/// If the concrete type cannot strip the resource type from the Id, it should just return the Id
	/// since the Id is a legitimate URL.
	/// This is basically assuming Feedly prefixes source feed URLs with `feed/`.
	/// It is not documented as such and could potentially change.
	/// Feedly does not include the source feed URL as a separate field.
	/// See https://developer.feedly.com/v3/feeds/#get-the-metadata-about-a-specific-feed
	var url: String {
		if let range = id.range(of: "feed/"), range.lowerBound == id.startIndex {
			var mutant = id
			mutant.removeSubrange(range)
			return mutant
		}

		// It seems values like "something/https://my.blog/posts.xml" is a legit URL.
		return id
	}
}

extension FeedlyFeedResourceId {
	init(url: String) {
		self.id = "feed/\(url)"
	}
}

struct FeedlyCategoryResourceId: FeedlyResourceId {
	let id: String

	enum Global {

		static func uncategorized(for userId: String) -> FeedlyCategoryResourceId {
			// https://developer.feedly.com/cloud/#global-resource-ids
			let id = "user/\(userId)/category/global.uncategorized"
			return FeedlyCategoryResourceId(id: id)
		}

		/// All articles from all the feeds the user subscribes to.
		static func all(for userId: String) -> FeedlyCategoryResourceId {
			// https://developer.feedly.com/cloud/#global-resource-ids
			let id = "user/\(userId)/category/global.all"
			return FeedlyCategoryResourceId(id: id)
		}

		/// All articles from all the feeds the user loves most.
		static func mustRead(for userId: String) -> FeedlyCategoryResourceId {
			// https://developer.feedly.com/cloud/#global-resource-ids
			let id = "user/\(userId)/category/global.must"
			return FeedlyCategoryResourceId(id: id)
		}
	}
}

struct FeedlyTagResourceId: FeedlyResourceId {
	let id: String

	enum Global {

		static func saved(for userId: String) -> FeedlyTagResourceId {
			// https://developer.feedly.com/cloud/#global-resource-ids
			let id = "user/\(userId)/tag/global.saved"
			return FeedlyTagResourceId(id: id)
		}
	}
}
