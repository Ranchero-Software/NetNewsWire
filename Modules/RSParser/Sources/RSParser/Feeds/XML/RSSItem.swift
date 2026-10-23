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
	var imageURL: String?
	var itunesImageURL: String?
	var itunesDurationInSeconds: Int?
	var mediaDescription: String?
	var mediaDescriptionIsHTML = false

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
			imageURL: imageURL ?? itunesImageURL,
			bannerImageURL: nil,
			datePublished: datePublished,
			dateModified: dateModified,
			authors: authors.isEmpty ? nil : authors,
			tags: nil,
			attachments: mergedAttachments()
		)
	}

	/// Podcast feeds often list the same file as both `<enclosure>` and `media:content`,
	/// so attachments with the same URL are merged into one. `itunes:duration` applies to
	/// audio and video attachments that don’t have their own duration.
	private func mergedAttachments() -> Set<ParsedAttachment>? {
		var attachmentsByURL = [String: ParsedAttachment]()
		for attachment in attachments {
			if let existingAttachment = attachmentsByURL[attachment.url] {
				attachmentsByURL[attachment.url] = existingAttachment.filledIn(from: attachment)
			} else {
				attachmentsByURL[attachment.url] = attachment
			}
		}
		guard !attachmentsByURL.isEmpty else {
			return nil
		}

		var mergedAttachments = Set<ParsedAttachment>()
		for var attachment in attachmentsByURL.values {
			if let itunesDurationInSeconds, attachment.durationInSeconds == nil, Self.isAudioOrVideo(attachment) {
				attachment = attachment.withDurationInSeconds(itunesDurationInSeconds)
			}
			mergedAttachments.insert(attachment)
		}
		return mergedAttachments
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
