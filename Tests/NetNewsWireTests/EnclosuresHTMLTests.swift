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
	@Test func podcastEpisodeGetsAudioPlayerAndArtwork() throws {
		let attachment = try #require(Attachment(url: "http://traffic.libsyn.com/atpfm/atp311.mp3", mimeType: "audio/mpeg", title: nil, sizeInBytes: 54919661, durationInSeconds: 6849, width: nil, height: nil, medium: .audio))
		let body = "<ul><li>Facebook’s Onavo scam</li><li>Apple’s FaceTime bug</li></ul>"
		let artworkURL = "http://static1.squarespace.com/static/513abd71e4b0fe58c655c105/t/52c45a37e4b0a77a5034aa84/1388599866232/1500w/Artwork.jpg"

		let html = ArticleRenderer.enclosuresHTML(attachments: [attachment], body: body, imageURL: artworkURL)

		#expect(html.contains("<audio controls preload=\"none\" src=\"http://traffic.libsyn.com/atpfm/atp311.mp3\"></audio>"))
		#expect(html.contains("atp311.mp3 · 1:54:09 · "))
		#expect(html.contains("<img src=\"\(artworkURL)\" alt=\"\">"))
	}

	// The body embeds the enclosure image, with `&` escaped in the src attribute.
	@Test func imageEnclosureAlreadyInBodyIsSkipped() throws {
		let imageURL = "https://storage.googleapis.com/gweb-cloudblog-publish/images/hero.max-1000x1000.png?w=1000&h=500"
		let attachment = try #require(Attachment(url: imageURL, mimeType: nil, title: nil, sizeInBytes: nil, durationInSeconds: nil, width: 1000, height: 500, medium: .image))
		let body = "<p><img src=\"https://storage.googleapis.com/gweb-cloudblog-publish/images/hero.max-1000x1000.png?w=1000&amp;h=500\"></p>"

		let html = ArticleRenderer.enclosuresHTML(attachments: [attachment], body: body, imageURL: imageURL)

		#expect(html.isEmpty)
	}
}
