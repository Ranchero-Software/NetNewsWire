//
//  FeedlyEntry.swift
//  Account
//
//  Created by Kiel Gillard on 19/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

enum Direction: String, Codable {
    case leftToRight = "ltr"
    case rightToLeft = "rtl"
}

struct FeedlyEntry: Decodable {
    /// the unique, immutable ID for this particular article.
    var id: String
    
    /// the article’s title. This string does not contain any HTML markup.
    var title: String?
    
    struct Content: Codable {
        var content: String?
        var direction: Direction?
    }
    
    /// This object typically has two values: “content” for the content itself, and “direction” (“ltr” for left-to-right, “rtl” for right-to-left). The content itself contains sanitized HTML markup.
    var content: Content?
    
    /// content object the article summary. See the content object above.
    var summary: Content?
    
    /// the author’s name
    var author: String?
    
//    ///  the immutable timestamp, in ms, when this article was processed by the feedly Cloud servers.
//    var crawled: Date
//
//    // the timestamp, in ms, when this article was re-processed and updated by the feedly Cloud servers.
//    var recrawled: Date?
//
    /// the timestamp, in ms, when this article was published, as reported by the RSS feed (often inaccurate).
    var published: Date

    /// the timestamp, in ms, when this article was updated, as reported by the RSS feed
    var updated: Date?
	
	/// the feed from which this article was crawled. If present, “streamId” will contain the feed id, “title” will contain the feed title, and “htmlUrl” will contain the feed’s website.
	var origin: FeedlyOrigin?
//
//    /// a list of alternate links for this article. Each link object contains a media type and a URL. Typically, a single object is present, with a link to the original web page.
//    var alternate: [Link]?
//
//    //        var origin:
//    //        Optional origin object the feed from which this article was crawled. If present, “streamId” will contain the feed id, “title” will contain the feed title, and “htmlUrl” will contain the feed’s website.
//    var keywords: [String]?
//
//    /// an image URL for this entry. If present, “url” will contain the image URL, “width” and “height” its dimension, and “contentType” its MIME type.
//    var visual: Image?
//
    /// Was this entry read by the user? If an Authorization header is not provided, this will always return false. If an Authorization header is provided, it will reflect if the user has read this entry or not.
    var unread: Bool
//
//    /// a list of tag objects (“id” and “label”) that the user added to this entry. This value is only returned if an Authorization header is provided, and at least one tag has been added. If the entry has been explicitly marked as read (not the feed itself), the “global.read” tag will be present.
//    var tags: [Tag]?
//
    /// a list of category objects (“id” and “label”) that the user associated with the feed of this entry. This value is only returned if an Authorization header is provided.
    var categories: [FeedlyCategory]?
//
//    /// an indicator of how popular this entry is. The higher the number, the more readers have read, saved or shared this particular entry.
//    var engagement: Int?
//
//    /// Timestamp for tagged articles, contains the timestamp when the article was tagged by the user. This will only be returned when the entry is returned through the streams API.
//    var actionTimestamp: Date?
//
//    /// A list of media links (videos, images, sound etc) provided by the feed. Some entries do not have a summary or content, only a collection of media links.
//    var enclosure: [Link]?
//
//    /// The article fingerprint. This value might change if the article is updated.
//    var fingerprint: String
    
    //        originId
    //        string the unique id of this post in the RSS feed (not necessarily a URL!)
    //        sid
    //        Optional string an internal search id.
}
