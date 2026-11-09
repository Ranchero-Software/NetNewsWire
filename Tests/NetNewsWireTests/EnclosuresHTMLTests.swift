//
//  EnclosuresHTMLTests.swift
//  NetNewsWireTests
//
//  Created by Brent Simmons on 10/24/26.
//

import Foundation
import Testing
import Articles

@testable import NetNewsWire

@MainActor @Suite struct EnclosuresHTMLTests {

	// ATP 311: an untitled audio enclosure, show notes in the body, and itunes:image as the article image.
	@Test func podcastEpisodeGetsArtworkAndAudioPlayer() throws {
		let attachment = try #require(Attachment(url: "http://traffic.libsyn.com/atpfm/atp311.mp3", mimeType: "audio/mpeg", title: nil, sizeInBytes: 54919661, durationInSeconds: 6849, width: nil, height: nil, medium: .audio))
		let body = "<ul><li>Facebook’s Onavo scam</li><li>Apple’s FaceTime bug</li></ul>"
		let artworkURL = "http://static1.squarespace.com/static/513abd71e4b0fe58c655c105/t/52c45a37e4b0a77a5034aa84/1388599866232/1500w/Artwork.jpg"

		let primaryMedia = try #require(ArticleRenderer.primaryMedia(imageLink: artworkURL, thumbnailLink: nil, attachments: [attachment], articleTitle: nil, body: body, bodyImageIdentities: ArticleRenderer.bodyImageIdentities(body, baseURL: nil)))

		#expect(primaryMedia.html.hasPrefix("<div class=\"nnw-primary-media\"><div class=\"nnw-primary-image\"><img src=\"\(artworkURL)\" alt=\"\"></div><div class=\"nnw-enclosure nnw-enclosure-audio\"><audio controls preload=\"none\" src=\"http://traffic.libsyn.com/atpfm/atp311.mp3\"></audio>"))
		#expect(primaryMedia.html.contains("atp311.mp3 · 1:54:09 · "))
		#expect(primaryMedia.attachmentURLs == [artworkURL, attachment.url])
	}

	// TWiT 1108: a video enclosure, and itunes:image as the article image, which is the video’s poster.
	@Test func videoEpisodeGetsVideoPlayerWithPoster() throws {
		let videoURL = "https://pscrb.fm/rss/p/mgln.ai/e/294/cdn.twit.tv/video/twit/twit1108/twit1108_h264m_1920x1080.mp4"
		let attachment = try #require(Attachment(url: videoURL, mimeType: "video/mp4", title: nil, sizeInBytes: 3010290787, durationInSeconds: nil, width: nil, height: nil, medium: .video))
		let body = "<p>Are we headed for a slow-motion collapse of the AI bubble, or is this just the next phase of tech’s endless hype cycle?</p>"
		let posterURL = "https://elroy.twit.tv/sites/default/files/styles/twit_thumb_720x405/public/images/episodes/2026/11/863590/hero/TWIT1108_thumbnail.jpg"

		let primaryMedia = try #require(ArticleRenderer.primaryMedia(imageLink: posterURL, thumbnailLink: nil, attachments: [attachment], articleTitle: "TWiT 1108: Bad AI Vibes - Why Tech Leaders Miss the Mark on AI’s Real Impact", body: body, bodyImageIdentities: ArticleRenderer.bodyImageIdentities(body, baseURL: nil)))

		#expect(primaryMedia.html == "<div class=\"nnw-primary-media\"><div class=\"nnw-enclosure nnw-enclosure-video\"><video controls preload=\"metadata\" playsinline src=\"\(videoURL)\" poster=\"\(posterURL)\"></video></div></div>")
		#expect(primaryMedia.attachmentURLs == [videoURL, posterURL])
	}

	// JSON Feed `image` that’s also listed as an attachment, which supplies the dimensions and title.
	@Test func primaryImageUsesMatchingAttachment() throws {
		let imageURL = "https://example.com/uploads/2026/11/heron.jpg"
		let attachment = try #require(Attachment(url: imageURL, mimeType: "image/jpeg", title: "Great blue heron at Green Lake", sizeInBytes: nil, durationInSeconds: nil, width: 1200, height: 800, medium: nil))
		let body = "<p>Spotted this morning on the north shore.</p>"

		let primaryImage = try #require(ArticleRenderer.primaryImage(imageLink: imageURL, thumbnailLink: nil, attachments: [attachment], body: body, bodyImageIdentities: ArticleRenderer.bodyImageIdentities(body, baseURL: nil)))

		#expect(ArticleRenderer.primaryImageHTML(primaryImage, articleTitle: nil) == "<div class=\"nnw-primary-image\"><img src=\"\(imageURL)\" alt=\"Great blue heron at Green Lake\" title=\"Great blue heron at Green Lake\" width=\"1200\" height=\"800\"><div class=\"nnw-primary-image-caption\">Great blue heron at Green Lake</div></div>")
	}

	// A feed that titles the image with the article’s title.
	@Test func primaryImageCaptionDroppedWhenSameAsArticleTitle() throws {
		let imageURL = "https://example.com/uploads/2026/11/heron.jpg"
		let image = try #require(Attachment(url: imageURL, mimeType: "image/jpeg", title: "Great Blue Heron at Green Lake", sizeInBytes: nil, durationInSeconds: nil, width: nil, height: nil, medium: nil))

		let html = ArticleRenderer.primaryImageHTML(image, articleTitle: "Great blue heron at Green Lake ")

		#expect(html == "<div class=\"nnw-primary-image\"><img src=\"\(imageURL)\" alt=\"Great Blue Heron at Green Lake\" title=\"Great Blue Heron at Green Lake\"></div>")
	}

	// Apple Newsroom: the image title has a non-breaking space in “MacBook Pro”, and the article title has a regular space and a trailing newline.
	@Test func primaryImageCaptionDroppedWhenSameAsArticleTitleExceptNonBreakingSpace() throws {
		let imageURL = "https://www.apple.com/newsroom/images/2026/10/apple-unveils-groundbreaking-macbook-pro-with-proled-xdr-display/tile/Apple-MacBook-Pro-with-PROLED-XDR-Display-Touch-experience-261028-lp.jpg.og.jpg"
		let image = try #require(Attachment(url: imageURL, mimeType: "image/jpeg", title: "Apple unveils groundbreaking MacBook\u{00A0}Pro with PROLED XDR Display", sizeInBytes: nil, durationInSeconds: nil, width: nil, height: nil, medium: nil))

		let html = ArticleRenderer.primaryImageHTML(image, articleTitle: "Apple unveils groundbreaking MacBook Pro with PROLED XDR Display\n")

		#expect(!html.contains("nnw-primary-image-caption"))
	}

	// The body has a WordPress resized copy of the image.
	@Test func primaryImageSkippedWhenBodyHasResizedCopy() {
		let imageURL = "https://example.com/uploads/2026/11/heron.jpg"
		let body = "<p><img src=\"https://example.com/uploads/2026/11/heron-1024x683.jpg\"></p>"

		#expect(ArticleRenderer.primaryImage(imageLink: imageURL, thumbnailLink: nil, attachments: nil, body: body, bodyImageIdentities: ArticleRenderer.bodyImageIdentities(body, baseURL: nil)) == nil)
	}

	// The Atlantic’s “The Democrats’ Fight Over Israel Is Just Beginning”: every image is `original.jpg` in its own folder,
	// and the body’s photos are different ones from the media:content image.
	@Test func primaryImageShownWhenBodyHasDifferentImages() throws {
		let imageURL = "https://cdn.theatlantic.com/thumbor/B7c5YtilnEF096Q7ZAci_1k_NF8=/media/img/mt/2026/11/2026_11_05_michigan_senate_4/original.jpg"
		let attachment = try #require(Attachment(url: imageURL, mimeType: nil, title: nil, sizeInBytes: nil, durationInSeconds: nil, width: nil, height: nil, medium: nil))
		let body = "<figure class=\"full-width\"><img src=\"https://cdn.theatlantic.com/thumbor/0ETPM-UWHuoYrFvGb63KD7sdkg8=/https://cdn.theatlantic.com/media/img/posts/2026/11/2026_11_05_michigan_senate_5/original.jpg\" width=\"982\" height=\"737\" alt=\"people talk at a dinner at a restaurant\"></figure>"

		#expect(ArticleRenderer.primaryImage(imageLink: nil, thumbnailLink: nil, attachments: [attachment], body: body, bodyImageIdentities: ArticleRenderer.bodyImageIdentities(body, baseURL: nil))?.url == imageURL)
	}

	// The Atlantic’s “Can Beauty Make Us Good?”: a YouTube embed in the body, and the artwork in media:content.
	@Test func primaryImageShownWhenBodyHasOnlyVideoEmbed() throws {
		let imageURL = "https://cdn.theatlantic.com/thumbor/s_Z10FAOXCdfHK2Nt6l15hAJjZM=/0x25:1919x1104/media/img/mt/2026/11/Elaine_Scarry_Permanent_Questions_Ollie_Artwork_/original.jpg"
		let attachment = try #require(Attachment(url: imageURL, mimeType: nil, title: nil, sizeInBytes: nil, durationInSeconds: nil, width: nil, height: nil, medium: nil))
		let body = "<p><iframe allowfullscreen=\"\" height=\"315\" src=\"https://www.youtube.com/embed/oymND7-uO-o?si=1WXJG8rZ_IaHorMQ\" title=\"YouTube video player\" width=\"560\"></iframe></p>"

		#expect(ArticleRenderer.primaryImage(imageLink: nil, thumbnailLink: nil, attachments: [attachment], body: body, bodyImageIdentities: ArticleRenderer.bodyImageIdentities(body, baseURL: nil))?.url == imageURL)
	}

	// Wired: no attachments, and the full-size lead image is in media:thumbnail.
	@Test func primaryImageFallsBackToThumbnail() {
		let thumbnailURL = "https://media.wired.com/photos/6aee77f4ece1c19963602401/master/pass/gear-nyt-cooking-ai-assistant.jpg"
		let body = "The New York Times has added a beta feature to its Cooking app that helps readers swap ingredients or adjust recipes to suit their needs. It mostly hits the mark."

		#expect(ArticleRenderer.primaryImage(imageLink: nil, thumbnailLink: thumbnailURL, attachments: nil, body: body, bodyImageIdentities: ArticleRenderer.bodyImageIdentities(body, baseURL: nil))?.url == thumbnailURL)
	}

	// The body embeds the enclosure image, with `&` escaped in the src attribute.
	@Test func imageEnclosureAlreadyInBodyIsSkipped() throws {
		let imageURL = "https://storage.googleapis.com/gweb-cloudblog-publish/images/hero.max-1000x1000.png?w=1000&h=500"
		let attachment = try #require(Attachment(url: imageURL, mimeType: nil, title: nil, sizeInBytes: nil, durationInSeconds: nil, width: 1000, height: 500, medium: .image))
		let body = "<p><img src=\"https://storage.googleapis.com/gweb-cloudblog-publish/images/hero.max-1000x1000.png?w=1000&amp;h=500\"></p>"

		let html = ArticleRenderer.enclosuresHTML(attachments: [attachment], body: body, bodyImageIdentities: ArticleRenderer.bodyImageIdentities(body, baseURL: nil), posterURL: nil)

		#expect(html.isEmpty)
	}

	// The Atlantic’s “Look Closer: A Mysterious Pair of Mittens”: the media:content image is a crop of the body’s photo.
	@Test func imageEnclosureCopyInBodyIsSkipped() throws {
		let imageURL = "https://cdn.theatlantic.com/thumbor/uIb4bjseN9GStI6B22iXaQrrOQU=/0x936:2400x2287/media/img/2026/11/Mittens_hi_res/original.jpg"
		let attachment = try #require(Attachment(url: imageURL, mimeType: nil, title: nil, sizeInBytes: nil, durationInSeconds: nil, width: nil, height: nil, medium: nil))
		let body = "<figure><img src=\"https://cdn.theatlantic.com/thumbor/XHxMrVONnyavd9kLpZD6DGfTxbo=/https://cdn.theatlantic.com/media/img/posts/2026/11/Mittens_hi_res/original.jpg\" alt=\"a pair of mittens\"></figure>"

		let html = ArticleRenderer.enclosuresHTML(attachments: [attachment], body: body, bodyImageIdentities: ArticleRenderer.bodyImageIdentities(body, baseURL: nil), posterURL: nil)

		#expect(html.isEmpty)
	}
}
