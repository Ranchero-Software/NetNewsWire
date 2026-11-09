//
//  ArticleRenderer+Enclosures.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/23/26.
//

import Foundation
import RSCore
import RSParser
import Articles

/// HTML for the `[[enclosures]]` substitution: players for audio and video, and images.
/// Styled with classes, since inline styles get stripped.
extension ArticleRenderer {

	private static let secondsPerMinute = 60
	private static let secondsPerHour = 3600
	/// A WordPress resized copy’s suffix, as in `heron-1024x683.jpg`.
	private static let wordPressSizeSuffix = #/-\d+x\d+(?=\.[A-Za-z0-9]+$)/#

	/// Empty when there’s nothing to show. Skips attachments already in the body, including resized copies,
	/// since feeds often embed the same image they list as an enclosure.
	/// `posterURL` is the poster for video enclosures.
	static func enclosuresHTML(attachments: [Attachment]?, body: String, bodyImageIdentities: Set<String>, posterURL: String?) -> String {
		let enclosures = (attachments ?? []).filter { !bodyContains($0.url, body: body, bodyImageIdentities: bodyImageIdentities) }.compactMap { enclosureHTML($0, posterURL: posterURL) }
		guard !enclosures.isEmpty else {
			return ""
		}
		return "<div class=\"nnw-enclosures\">\n\(enclosures.joined(separator: "\n"))\n</div>"
	}

	static func dimensionAttributes(_ attachment: Attachment) -> String {
		guard let width = attachment.width, let height = attachment.height else {
			return ""
		}
		return " width=\"\(width)\" height=\"\(height)\""
	}

	/// The `imageIdentity` of each of the body’s images, for spotting resized copies.
	static func bodyImageIdentities(_ body: String, baseURL: URL?) -> Set<String> {
		Set(HTMLImageParser.significantImageURLStrings(html: body, baseURL: baseURL, maximumCount: Int.max).compactMap(imageIdentity))
	}

	/// True when the body has `url`, or a resized copy of the image at `url`.
	static func bodyContains(_ url: String, body: String, bodyImageIdentities: Set<String>) -> Bool {
		if bodyContainsURL(body, url) {
			return true
		}
		guard let identity = imageIdentity(url) else {
			return false
		}
		return bodyImageIdentities.contains(identity)
	}

	/// A player or image for one attachment. Nil when it’s not something that can be shown.
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

}

private extension ArticleRenderer {

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

	/// The last two path components, lowercased, without a WordPress size suffix.
	/// Two components, since some sites name every image `original.jpg` in its own folder.
	/// Ignores the host and query, since resized copies are often served through a resizing service.
	static func imageIdentity(_ urlString: String) -> String? {
		guard let url = URL(string: urlString) else {
			return nil
		}
		let pathComponents = url.pathComponents.filter { $0 != "/" }
		guard let fileName = pathComponents.last else {
			return nil
		}
		let folderName = pathComponents.dropLast().suffix(1)
		return (folderName + [fileName.replacing(wordPressSizeSuffix, with: "")]).joined(separator: "/").lowercased()
	}
}
