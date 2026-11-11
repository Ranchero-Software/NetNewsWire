//
//  ArticleRenderer+PrimaryMedia.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/8/26.
//

import Foundation
import RSCore
import Articles

/// The article’s main media, for the `[[primary_media]]` substitution: a video, else audio with the article image, else the article image.
extension ArticleRenderer {

	typealias PrimaryMedia = (html: String, attachmentURLs: Set<String>)

	private static let shortPostMaximumBodyLength = 2048

	/// Untitled and short, as with Mastodon and microblog posts, which put their images after the text.
	/// Their images go in the enclosures, not the primary media.
	static func isShortUntitledPost(title: String?, body: String) -> Bool {
		guard title?.isEmpty ?? true else {
			return false
		}
		return body.count < shortPostMaximumBodyLength
	}

	/// Nil when there’s nothing to show. `attachmentURLs` are the attachments (and article image) it shows, for the enclosures to skip.
	/// A video’s poster is the article image or thumbnail, so the image isn’t shown separately.
	/// When `includesImage` is false, only a video or audio is shown.
	static func primaryMedia(imageLink: String?, thumbnailLink: String?, attachments: [Attachment]?, articleTitle: String?, body: String, bodyImageIdentities: Set<String>, includesImage: Bool) -> PrimaryMedia? {
		let playableAttachments = (attachments ?? []).filter { !bodyContains($0.url, body: body, bodyImageIdentities: bodyImageIdentities) }

		let posterURL = imageLink ?? thumbnailLink
		if let video = playableAttachments.first(where: isVideo), let videoHTML = enclosureHTML(video, posterURL: posterURL) {
			var attachmentURLs: Set<String> = [video.url]
			if let posterURL {
				attachmentURLs.insert(posterURL)
			}
			return (primaryMediaHTML(videoHTML), attachmentURLs)
		}

		var imageHTML = ""
		var attachmentURLs = Set<String>()
		if includesImage, let image = primaryImage(imageLink: imageLink, thumbnailLink: thumbnailLink, attachments: attachments, body: body, bodyImageIdentities: bodyImageIdentities) {
			imageHTML = primaryImageHTML(image, articleTitle: articleTitle)
			attachmentURLs.insert(image.url)
		}

		if let audio = playableAttachments.first(where: { $0.displayMedium == .audio }), let audioHTML = enclosureHTML(audio, posterURL: nil) {
			attachmentURLs.insert(audio.url)
			return (primaryMediaHTML(imageHTML + audioHTML), attachmentURLs)
		}

		guard !imageHTML.isEmpty else {
			return nil
		}
		return (primaryMediaHTML(imageHTML), attachmentURLs)
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

	static func primaryMediaHTML(_ html: String) -> String {
		"<div class=\"nnw-primary-media\">\(html)</div>"
	}

	static func isVideo(_ attachment: Attachment) -> Bool {
		attachment.displayMedium == .video || ArticleRenderingSpecialCases.youTubeEmbedURL(forAttachmentURL: attachment.url) != nil
	}

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
