//
//  ArticleRenderer+PrimaryImage.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/8/26.
//

import Foundation
import RSCore
import Articles

/// The article’s main image, for the `[[primary_image]]` substitution.
extension ArticleRenderer {

	/// The article image (JSON Feed `image`, `itunes:image`, or a sync service’s image), else the first image attachment.
	/// Nil when the body already has the image, or a resized copy of it at a different URL.
	/// An attachment with the same URL supplies the dimensions and title.
	static func primaryImage(imageLink: String?, attachments: [Attachment]?, body: String, bodyImageIdentities: Set<String>) -> Attachment? {
		let attachments = attachments ?? []
		let image: Attachment?
		if let imageLink, !imageLink.isEmpty {
			image = attachments.first { $0.url == imageLink } ?? Attachment(url: imageLink, mimeType: nil, title: nil, sizeInBytes: nil, durationInSeconds: nil, width: nil, height: nil, medium: .image)
		} else {
			image = attachments.first { $0.displayMedium == .image }
		}

		guard let image, !bodyContains(image.url, body: body, bodyImageIdentities: bodyImageIdentities) else {
			return nil
		}
		return image
	}

	/// No caption when the image’s title is the same as the article’s.
	static func primaryImageHTML(_ image: Attachment, articleTitle: String?) -> String {
		var attributes = "src=\"\(image.url.escapingSpecialXMLCharacters)\""
		var caption = ""
		if let title = image.title, !title.isEmpty {
			let escapedTitle = title.escapingSpecialXMLCharacters
			attributes += " alt=\"\(escapedTitle)\" title=\"\(escapedTitle)\""
			if !isSameTitle(title, articleTitle) {
				caption = "<div class=\"nnw-primary-image-caption\">\(escapedTitle)</div>"
			}
		} else {
			attributes += " alt=\"\""
		}
		attributes += dimensionAttributes(image)
		return "<div class=\"nnw-primary-image\"><img \(attributes)>\(caption)</div>"
	}
}

private extension ArticleRenderer {

	static func isSameTitle(_ imageTitle: String, _ articleTitle: String?) -> Bool {
		guard let articleTitle else {
			return false
		}
		return collapsingWhitespace(imageTitle).caseInsensitiveCompare(collapsingWhitespace(articleTitle)) == .orderedSame
	}

	/// Each run of whitespace, including non-breaking spaces, becomes one space, and the ends are trimmed.
	/// Apple Newsroom puts non-breaking spaces in image titles (“MacBook Pro”) but not in article titles.
	static func collapsingWhitespace(_ s: String) -> String {
		s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
	}
}
