//
//  RSSItem.swift
//  RSParser
//
//  Created by Brent Simmons on 2026-04-24.
//

import Foundation
import RSCore

/// Feed item shared by the RSS and Atom parsers.
final class RSSItem {

	var guid: String?
	var title: String?
	var body: String?
	var summary: String?
	var markdown: String?
	var link: String?        // External link
	var permalink: String?   // URL of the item itself
	var language: String?
	var datePublished: Date?
	var dateModified: Date?
	var authors: Set<ParsedAuthor> = []
	var attachments: [ParsedAttachment] = []
	var thumbnailURL: String?
	var itunesImageURL: String?
	var itunesDurationInSeconds: Int?
	var mediaDescription: String?
	var mediaDescriptionIsHTML = false
	/// `media:title` of each Gravatar `media:content`, by URL.
	var gravatarTitlesByURL = [String: String]()

	/// Returns `guid` if present. Otherwise MD5-hashes available properties
	/// to build the most likely stable ID.
	///
	/// Don't change this without a super-good reason! It would mean article IDs
	/// would no longer match, and people would have many duplicates.
	var uniqueID: String {
		if let guid, !guid.isEmpty {
			return guid
		}

		let datePublishedString: String?
		if let datePublished {
			datePublishedString = String(format: "%.0f", datePublished.timeIntervalSince1970)
		} else {
			datePublishedString = nil
		}

		var s = ""
		if let permalink, !permalink.isEmpty, let datePublishedString {
			s = permalink + datePublishedString
		} else if let link, !link.isEmpty, let datePublishedString {
			s = link + datePublishedString
		} else if let title, !title.isEmpty, let datePublishedString {
			s = title + datePublishedString
		} else if let datePublishedString {
			s = datePublishedString
		} else if let permalink, !permalink.isEmpty {
			s = permalink
		} else if let link, !link.isEmpty {
			s = link
		} else if let title, !title.isEmpty {
			s = title
		} else if let body, !body.isEmpty {
			s = body
		}
		return s.md5String
	}

	func toParsedItem(feedURL: String) -> ParsedItem {
		// If body is empty and summary has content,
		// promote summary to body and drop summary.
		var contentHTML = body
		var itemSummary = summary
		if contentHTML == nil || contentHTML?.isEmpty == true, let s = itemSummary, !s.isEmpty {
			contentHTML = s
			itemSummary = nil
		}

		// With no body or summary, fall back to media:description (YouTube, for instance).
		var contentText: String?
		if contentHTML == nil || contentHTML?.isEmpty == true, let mediaDescription {
			if mediaDescriptionIsHTML {
				contentHTML = mediaDescription
			} else {
				contentText = mediaDescription
			}
		}

		let (authorsWithAvatars, avatarURLs) = authorsWithGravatars()

		return ParsedItem(
			syncServiceID: nil,
			uniqueID: uniqueID,
			feedURL: feedURL,
			url: permalink,
			externalURL: link,
			title: title,
			language: language,
			contentHTML: contentHTML,
			contentText: contentText,
			markdown: markdown,
			summary: itemSummary,
			imageURL: itunesImageURL,
			thumbnailURL: thumbnailURL,
			bannerImageURL: nil,
			datePublished: datePublished,
			dateModified: dateModified,
			authors: authorsWithAvatars.isEmpty ? nil : authorsWithAvatars,
			tags: nil,
			attachments: mergedAttachments(attachments.filter { !avatarURLs.contains($0.url) })
		)
	}

	/// WordPress adds each post author’s Gravatar as a `media:content` titled with the author’s name.
	/// A match becomes the author’s avatar instead of an attachment.
	private func authorsWithGravatars() -> (authors: Set<ParsedAuthor>, avatarURLs: Set<String>) {
		var avatarURLs = Set<String>()
		let authorsWithAvatars = Set(authors.map { author in
			guard author.avatarURL == nil, let name = author.name, let avatarURL = gravatarURL(authorName: name) else {
				return author
			}
			avatarURLs.insert(avatarURL)
			return ParsedAuthor(name: author.name, url: author.url, avatarURL: avatarURL, emailAddress: author.emailAddress)
		})
		return (authorsWithAvatars, avatarURLs)
	}

	private func gravatarURL(authorName: String) -> String? {
		gravatarTitlesByURL.first { $0.value.caseInsensitiveCompare(authorName) == .orderedSame }?.key
	}

	/// Podcast feeds often list the same file as both `<enclosure>` and `media:content`,
	/// so attachments with the same URL are merged into one, in the place of the first.
	/// `itunes:duration` applies to audio and video attachments that don’t have their own duration.
	private func mergedAttachments(_ attachments: [ParsedAttachment]) -> [ParsedAttachment]? {
		var mergedAttachments = [ParsedAttachment]()
		var indexesByURL = [String: Int]()
		for attachment in attachments {
			if let index = indexesByURL[attachment.url] {
				mergedAttachments[index] = mergedAttachments[index].filledIn(from: attachment)
			} else {
				indexesByURL[attachment.url] = mergedAttachments.count
				mergedAttachments.append(attachment)
			}
		}
		guard !mergedAttachments.isEmpty else {
			return nil
		}

		guard let itunesDurationInSeconds else {
			return mergedAttachments
		}
		return mergedAttachments.map { attachment in
			guard attachment.durationInSeconds == nil, Self.isAudioOrVideo(attachment) else {
				return attachment
			}
			return attachment.withDurationInSeconds(itunesDurationInSeconds)
		}
	}

	private static func isAudioOrVideo(_ attachment: ParsedAttachment) -> Bool {
		if attachment.medium == .audio || attachment.medium == .video {
			return true
		}
		guard let mimeType = attachment.mimeType?.lowercased() else {
			return false
		}
		return mimeType.hasPrefix("audio/") || mimeType.hasPrefix("video/")
	}
}
