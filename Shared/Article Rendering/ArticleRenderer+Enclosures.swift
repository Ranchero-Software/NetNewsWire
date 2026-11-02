//
//  ArticleRenderer+Enclosures.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/23/26.
//

import Foundation
import RSCore
import Articles

/// HTML for the `[[enclosures]]` substitution: players for audio and video, and images.
/// Styled with classes, since inline styles get stripped.
extension ArticleRenderer {

	private static let secondsPerMinute = 60
	private static let secondsPerHour = 3600
	private static let visualElementTags = ["<img", "<picture", "<video", "<iframe"]

	/// Empty when there’s nothing to show. Skips attachments whose URLs already appear
	/// in the body, since feeds often embed the same image they list as an enclosure.
	/// `imageURL` (the article’s image, else its thumbnail) is shown only when nothing
	/// else visual is — no image or video enclosure, and no image or video in the body.
	static func enclosuresHTML(attachments: [Attachment]?, body: String, imageURL: String?) -> String {
		var enclosures = [String]()
		var hasVisualEnclosure = false
		for attachment in attachments ?? [] where !bodyContainsURL(body, attachment.url) {
			if let enclosure = enclosureHTML(attachment, posterURL: imageURL) {
				enclosures.append(enclosure)
				hasVisualEnclosure = hasVisualEnclosure || isVisual(attachment)
			}
		}

		if !hasVisualEnclosure, let imageURL, !imageURL.isEmpty, !bodyContainsVisualElement(body), !bodyContainsURL(body, imageURL) {
			let image = "<div class=\"nnw-enclosure nnw-enclosure-image\"><img src=\"\(imageURL.escapingSpecialXMLCharacters)\" alt=\"\"></div>"
			enclosures.insert(image, at: 0)
		}

		guard !enclosures.isEmpty else {
			return ""
		}
		return "<div class=\"nnw-enclosures\">\n\(enclosures.joined(separator: "\n"))\n</div>"
	}
}

private extension ArticleRenderer {

	static func enclosureHTML(_ attachment: Attachment, posterURL: String?) -> String? {
		if let youTubeEmbedURL = ArticleRenderingSpecialCases.youTubeEmbedURL(forAttachmentURL: attachment.url) {
			let iframe = "<iframe src=\"\(youTubeEmbedURL)\"" + dimensionAttributes(attachment) + " allowfullscreen></iframe>"
			return "<div class=\"nnw-enclosure nnw-enclosure-video\">\(iframe)</div>"
		}

		guard let displayMedium = attachment.displayMedium else {
			return nil
		}

		let src = attachment.url.escapingSpecialXMLCharacters
		let mediaElement: String
		let caption: String?

		switch displayMedium {
		case .audio:
			mediaElement = "<audio controls preload=\"none\" src=\"\(src)\"></audio>"
			caption = audioCaption(attachment)
		case .video:
			var attributes = "controls preload=\"metadata\" playsinline src=\"\(src)\"" + dimensionAttributes(attachment)
			if let posterURL, !posterURL.isEmpty {
				attributes += " poster=\"\(posterURL.escapingSpecialXMLCharacters)\""
			}
			mediaElement = "<video \(attributes)></video>"
			caption = attachment.title
		case .image:
			mediaElement = "<img src=\"\(src)\" alt=\"\"" + dimensionAttributes(attachment) + ">"
			caption = attachment.title
		case .document, .executable:
			return nil
		}

		var html = "<div class=\"nnw-enclosure nnw-enclosure-\(displayMedium.rawValue)\">\(mediaElement)"
		if let caption, !caption.isEmpty {
			html += "<div class=\"nnw-enclosure-caption\">\(caption.escapingSpecialXMLCharacters)</div>"
		}
		html += "</div>"
		return html
	}

	/// Title (or file name), duration, and size, such as “Episode 311 · 1:54:09 · 54.9 MB”.
	static func audioCaption(_ attachment: Attachment) -> String {
		var components = [String]()
		if let title = attachment.title, !title.isEmpty {
			components.append(title)
		} else if let fileName = fileName(attachment.url) {
			components.append(fileName)
		}
		if let durationInSeconds = attachment.durationInSeconds {
			components.append(durationString(durationInSeconds))
		}
		if let sizeInBytes = attachment.sizeInBytes {
			components.append(ByteCountFormatter.string(fromByteCount: Int64(sizeInBytes), countStyle: .file))
		}
		return components.joined(separator: " · ")
	}

	static func dimensionAttributes(_ attachment: Attachment) -> String {
		guard let width = attachment.width, let height = attachment.height else {
			return ""
		}
		return " width=\"\(width)\" height=\"\(height)\""
	}

	static func durationString(_ durationInSeconds: Int) -> String {
		let hours = durationInSeconds / secondsPerHour
		let minutes = (durationInSeconds % secondsPerHour) / secondsPerMinute
		let seconds = durationInSeconds % secondsPerMinute
		if hours > 0 {
			return String(format: "%d:%02d:%02d", hours, minutes, seconds)
		}
		return String(format: "%d:%02d", minutes, seconds)
	}

	static func fileName(_ urlString: String) -> String? {
		guard let lastPathComponent = URL(string: urlString)?.lastPathComponent, !lastPathComponent.isEmpty, lastPathComponent != "/" else {
			return nil
		}
		return lastPathComponent.removingPercentEncoding ?? lastPathComponent
	}

	static func isVisual(_ attachment: Attachment) -> Bool {
		if ArticleRenderingSpecialCases.youTubeEmbedURL(forAttachmentURL: attachment.url) != nil {
			return true
		}
		return attachment.displayMedium == .image || attachment.displayMedium == .video
	}

	static func bodyContainsVisualElement(_ body: String) -> Bool {
		visualElementTags.contains { body.range(of: $0, options: .caseInsensitive) != nil }
	}

	/// Body HTML escapes `&` in attributes, so check both forms of the URL.
	static func bodyContainsURL(_ body: String, _ url: String) -> Bool {
		body.contains(url) || body.contains(url.escapingSpecialXMLCharacters)
	}
}
