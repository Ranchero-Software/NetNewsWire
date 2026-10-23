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

	/// Empty when there’s nothing to show. Skips attachments whose URLs already appear
	/// in the body, since feeds often embed the same image they list as an enclosure.
	static func enclosuresHTML(attachments: Set<Attachment>?, body: String, posterURL: String?) -> String {
		guard let attachments, !attachments.isEmpty else {
			return ""
		}

		let sortedAttachments = attachments.sorted { $0.url < $1.url }
		var enclosures = [String]()
		for attachment in sortedAttachments where !bodyContainsURL(body, attachment.url) {
			if let enclosure = enclosureHTML(attachment, posterURL: posterURL) {
				enclosures.append(enclosure)
			}
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
			return "<figure class=\"nnw-enclosure nnw-enclosure-video\">\(iframe)</figure>"
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

		var html = "<figure class=\"nnw-enclosure nnw-enclosure-\(displayMedium.rawValue)\">\(mediaElement)"
		if let caption, !caption.isEmpty {
			html += "<figcaption>\(caption.escapingSpecialXMLCharacters)</figcaption>"
		}
		html += "</figure>"
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

	/// Body HTML escapes `&` in attributes, so check both forms of the URL.
	static func bodyContainsURL(_ body: String, _ url: String) -> Bool {
		body.contains(url) || body.contains(url.escapingSpecialXMLCharacters)
	}
}
