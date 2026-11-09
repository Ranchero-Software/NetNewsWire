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

	private static let shortPostMaximumBodyLength = 2048

	/// Untitled and short, as with social media and microblog posts, which put their images after the text.
	/// These get no primary image — its image goes in the enclosures.
	static func isShortUntitledPost(title: String?, body: String) -> Bool {
		guard title?.isEmpty ?? true else {
			return false
		}
		return body.count < shortPostMaximumBodyLength
	}

	/// The article image (JSON Feed `image`, `itunes:image`, or a sync service’s image), else the first image attachment,
	/// else the thumbnail (`media:thumbnail`, which Wired uses for its full-size lead image).
	/// Nil when the body already has the image, or a resized copy of it at a different URL.
	/// An attachment with the same URL supplies the dimensions and title.
	static func primaryImage(imageLink: String?, thumbnailLink: String?, attachments: [Attachment]?, body: String, bodyImageIdentities: Set<String>) -> Attachment? {
		let attachments = attachments ?? []
		let image: Attachment?
		if let imageLink, !imageLink.isEmpty {
			image = attachments.first { $0.url == imageLink } ?? imageAttachment(imageLink)
		} else if let firstImageAttachment = attachments.first(where: { $0.displayMedium == .image }) {
			image = firstImageAttachment
		} else if let thumbnailLink, !thumbnailLink.isEmpty {
			image = imageAttachment(thumbnailLink)
		} else {
			image = nil
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

	static func imageAttachment(_ url: String) -> Attachment? {
		Attachment(url: url, mimeType: nil, title: nil, sizeInBytes: nil, durationInSeconds: nil, width: nil, height: nil, medium: .image)
	}

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
