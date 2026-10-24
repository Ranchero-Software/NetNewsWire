//
//  MediaRSS.swift
//  RSParser
//
//  Created by Brent Simmons on 10/22/26.
//

import Foundation

/// Media RSS and iTunes helpers shared by the RSS and Atom parsers.
enum MediaRSS {

	/// Attachment from a `media:content` element’s attributes. `url` is the resolved `url` attribute.
	static func attachment(url: String, attributes: XMLAttributes) -> ParsedAttachment? {

		let mimeType = attributes.value(forNameCaseInsensitive: "type")
		// The spec says fileSize. Some feeds (atp.fm) use length, as in RSS enclosures.
		let sizeInBytes = positiveInt(attributes.value(forNameCaseInsensitive: "fileSize") ?? attributes.value(forNameCaseInsensitive: "length"))
		let durationInSeconds = ParsedAttachment.durationInSeconds(attributes.value(forNameCaseInsensitive: "duration"))
		let width = positiveInt(attributes.value(forNameCaseInsensitive: "width"))
		let height = positiveInt(attributes.value(forNameCaseInsensitive: "height"))
		let mediumValue = attributes.value(forNameCaseInsensitive: "medium")
		let medium = ParsedAttachment.Medium(mediaRSSValue: mediumValue)

		return ParsedAttachment(url: url, mimeType: mimeType, title: nil, sizeInBytes: sizeInBytes, durationInSeconds: durationInSeconds, width: width, height: height, medium: medium)
	}

	static func isDefault(_ attributes: XMLAttributes) -> Bool {
		attributes.value(forNameCaseInsensitive: "isDefault")?.lowercased() == "true"
	}

	private static func positiveInt(_ s: String?) -> Int? {
		guard let s, let value = Int(s.trimmingCharacters(in: .whitespacesAndNewlines)), value > 0 else {
			return nil
		}
		return value
	}
}

/// Tracks `media:group` and `media:content` while parsing an item, adding attachments,
/// the thumbnail, and the description to the item. Used by the RSS and Atom parsers.
struct MediaElementTracker {

	/// Depth inside `media:group`, `media:content`, and `media:description`. The parsers skip
	/// non-Media RSS elements in there, so an unprefixed child (`<title>`)
	/// can’t be mistaken for one of the item’s own elements.
	private(set) var containerDepth = 0

	private var group: MediaGroup?

	mutating func reset() {
		containerDepth = 0
		group = nil
	}

	/// Returns true when the parser should skip the element’s subtree.
	mutating func start(localName: ArraySlice<UInt8>, attributes: XMLAttributes, item: RSSItem, parser: XMLSAXParser, resolveURL: (String) -> String?) -> Bool {
		if localName.equals("group") {
			group = MediaGroup()
			containerDepth += 1
			return false
		}

		if localName.equals("content") {
			if let urlString = attributes.value(forNameCaseInsensitive: "url"), let url = resolveURL(urlString), let attachment = MediaRSS.attachment(url: url, attributes: attributes) {
				if group != nil {
					group?.add(attachment, isDefault: MediaRSS.isDefault(attributes))
				} else {
					item.attachments.append(attachment)
				}
			}
			containerDepth += 1
			return false
		}

		if localName.equals("description") {
			if item.mediaDescription == nil {
				item.mediaDescriptionIsHTML = attributes.value(forNameCaseInsensitive: "type")?.lowercased() == "html"
				parser.beginStoringCharacters()
			}
			containerDepth += 1
			return false
		}

		if localName.equals("thumbnail"), item.thumbnailURL == nil, let urlString = attributes.value(forNameCaseInsensitive: "url"), !urlString.isEmpty {
			item.thumbnailURL = resolveURL(urlString)
		}
		return true
	}

	mutating func end(localName: ArraySlice<UInt8>, item: RSSItem, parser: XMLSAXParser) {
		if localName.equals("group") {
			if let attachment = group?.chosenAttachment {
				item.attachments.append(attachment)
			}
			group = nil
			containerDepth -= 1
		} else if localName.equals("content") {
			containerDepth -= 1
		} else if localName.equals("description") {
			if item.mediaDescription == nil {
				item.mediaDescription = parser.currentStringWithTrimmedWhitespace
			}
			containerDepth -= 1
		}
	}
}

/// Collects the renditions in a `media:group`. They’re alternates of one thing,
/// so only one is kept: the `isDefault` one, else the first.
private struct MediaGroup {

	private var defaultAttachment: ParsedAttachment?
	private var firstAttachment: ParsedAttachment?

	var chosenAttachment: ParsedAttachment? {
		defaultAttachment ?? firstAttachment
	}

	mutating func add(_ attachment: ParsedAttachment, isDefault: Bool) {
		if firstAttachment == nil {
			firstAttachment = attachment
		}
		if isDefault && defaultAttachment == nil {
			defaultAttachment = attachment
		}
	}
}

extension ParsedAttachment.Medium {

	/// Case-insensitive. Nil for values the Media RSS spec doesn’t define.
	public init?(mediaRSSValue: String?) {
		guard let mediaRSSValue else {
			return nil
		}
		self.init(rawValue: mediaRSSValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
	}
}
