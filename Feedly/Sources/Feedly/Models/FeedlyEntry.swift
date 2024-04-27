//
//  FeedlyEntry.swift
//  Account
//
//  Created by Kiel Gillard on 19/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

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
