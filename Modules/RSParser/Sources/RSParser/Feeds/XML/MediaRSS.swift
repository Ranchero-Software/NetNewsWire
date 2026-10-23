//
//  MediaRSS.swift
//  RSParser
//
//  Created by Brent Simmons on 10/22/26.
//

import Foundation

/// Media RSS and iTunes helpers shared by the RSS and Atom parsers.
enum MediaRSS {

	/// Attachment from a `media:content` element’s attributes.
	static func attachment(_ attributes: XMLAttributes) -> ParsedAttachment? {
		guard let url = attributes.value(forNameCaseInsensitive: "url") else {
			return nil
		}

		let mimeType = attributes.value(forNameCaseInsensitive: "type")
		// The spec says fileSize. Some feeds (atp.fm) use length, as in RSS enclosures.
		let sizeInBytes = positiveInt(attributes.value(forNameCaseInsensitive: "fileSize") ?? attributes.value(forNameCaseInsensitive: "length"))
		let durationInSeconds = durationInSeconds(attributes.value(forNameCaseInsensitive: "duration"))
		let width = positiveInt(attributes.value(forNameCaseInsensitive: "width"))
		let height = positiveInt(attributes.value(forNameCaseInsensitive: "height"))
		let mediumValue = attributes.value(forNameCaseInsensitive: "medium")
		let medium = ParsedAttachment.Medium(mediaRSSValue: mediumValue)

		return ParsedAttachment(url: url, mimeType: mimeType, title: nil, sizeInBytes: sizeInBytes, durationInSeconds: durationInSeconds, width: width, height: height, medium: medium)
	}

	static func isDefault(_ attributes: XMLAttributes) -> Bool {
		attributes.value(forNameCaseInsensitive: "isDefault")?.lowercased() == "true"
	}

	private static let maximumDurationComponentCount = 3 // 1:00:00

	/// Parses plain seconds (`3600`, `3600.5`) and clock forms (`1:00:00`, `59:30`).
	static func durationInSeconds(_ s: String?) -> Int? {
		guard let s else {
			return nil
		}
		let components = s.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":", omittingEmptySubsequences: false)
		guard components.count <= maximumDurationComponentCount else {
			return nil
		}

		var seconds = 0.0
		for component in components {
			guard let value = Double(component), value.isFinite, value >= 0 else {
				return nil
			}
			seconds = seconds * 60 + value
		}

		guard let wholeSeconds = Int(exactly: seconds.rounded(.down)), wholeSeconds > 0 else {
			return nil
		}
		return wholeSeconds
	}

	private static func positiveInt(_ s: String?) -> Int? {
		guard let s, let value = Int(s.trimmingCharacters(in: .whitespacesAndNewlines)), value > 0 else {
			return nil
		}
		return value
	}
}

/// Collects the renditions in a `media:group`. They’re alternates of one thing,
/// so only one is kept: the `isDefault` one, else the first.
struct MediaGroup {

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
	init?(mediaRSSValue: String?) {
		guard let mediaRSSValue else {
			return nil
		}
		self.init(rawValue: mediaRSSValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
	}
}
