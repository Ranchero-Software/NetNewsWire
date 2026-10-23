//
//  AttachmentTests.swift
//  ArticlesTests
//
//  Created by Brent Simmons on 10/23/26.
//

import Foundation
import Testing
import Articles

@Suite struct AttachmentTests {

	@Test func displayMedium() throws {
		// Podcast enclosure served as a generic binary type: the file extension decides.
		let podcast = try #require(Attachment(url: "https://example.com/episode.mp3", mimeType: "application/octet-stream", title: nil, sizeInBytes: nil, durationInSeconds: nil, width: nil, height: nil, medium: nil))
		#expect(podcast.displayMedium == .audio)

		// atp.fm items with no type attribute, only medium.
		let atp = try #require(Attachment(url: "http://traffic.libsyn.com/atpfm/atp309.mp3", mimeType: nil, title: nil, sizeInBytes: nil, durationInSeconds: nil, width: nil, height: nil, medium: .audio))
		#expect(atp.displayMedium == .audio)

		// cloudblog.rss image with no type or medium.
		let image = try #require(Attachment(url: "https://storage.googleapis.com/gweb-cloudblog-publish/images/shadow_IT.max-600x600.png", mimeType: nil, title: nil, sizeInBytes: nil, durationInSeconds: nil, width: 540, height: 540, medium: nil))
		#expect(image.displayMedium == .image)

		// YouTube’s Flash player URL isn’t displayable.
		let youTube = try #require(Attachment(url: "https://www.youtube.com/v/abcdefghijk?version=3", mimeType: "application/x-shockwave-flash", title: nil, sizeInBytes: nil, durationInSeconds: nil, width: 640, height: 390, medium: nil))
		#expect(youTube.displayMedium == nil)
	}
}
