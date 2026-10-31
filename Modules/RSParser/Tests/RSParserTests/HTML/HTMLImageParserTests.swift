//
//  HTMLImageParserTests.swift
//  RSParserTests
//
//  Created by Brent Simmons on 10/25/26.
//

import Foundation
import Testing
import RSParser

@Suite struct HTMLImageParserTests {

	@Test func smileysAreSkipped() throws {
		let parsedFeed = try #require(try FeedParser.parse(parserData("natasha", "xml", "https://www.natashatherobot.com/feed/")))
		var foundImageCount = 0

		for item in parsedFeed.items {
			guard let html = item.contentHTML else {
				continue
			}
			let image = HTMLImageParser.significantImages(html: html, baseURL: URL(string: item.url ?? ""), maximumCount: 1).first
			if let image {
				foundImageCount += 1
				#expect(!image.urlString.contains("s.w.org"))
			}
			if item.url == "https://www.natashatherobot.com/url-apple-wallet-passkit-pass/" {
				// The first image is 503×88, too wide to stand for the article.
				#expect(image?.urlString == "https://www.natashatherobot.com/wp-content/uploads/Screen-Shot-2017-07-07-at-12.35.13-PM.png")
			}
		}

		#expect(foundImageCount > 0)
	}

	@Test func feedBurnerFlaresAndTrackingPixelAreSkipped() {
		let html = """
		<p>Text.</p>
		<div class="feedflare">
		<a href="http://feeds.feedburner.com/~ff/Example?a=abc"><img src="http://feeds.feedburner.com/~ff/Example?d=yIl2AUoC8zA" border="0"></a>
		</div>
		<img src="http://feeds.feedburner.com/~r/Example/~4/xyz" height="1" width="1" alt=""/>
		"""
		#expect(firstSignificantImage(html) == nil)
	}

	@Test func shareButtonsAreSkipped() {
		let html = """
		<div class="sharedaddy">
		<a href="https://www.facebook.com/sharer/sharer.php?u=https%3A%2F%2Fexample.com%2Fposts%2F1"><img src="/wp-content/plugins/share/facebook.png"></a>
		<a href="https://twitter.com/intent/tweet?url=https%3A%2F%2Fexample.com%2Fposts%2F1"><img src="/wp-content/plugins/share/twitter.png"></a>
		<a href="mailto:?subject=Post&amp;body=https%3A%2F%2Fexample.com%2Fposts%2F1"><img src="/wp-content/plugins/share/email.png"></a>
		</div>
		<a href="https://example.com/photo-large.jpg"><img src="https://example.com/photo.jpg"></a>
		"""
		#expect(firstSignificantImage(html)?.urlString == "https://example.com/photo.jpg")
	}

	@Test func trackingPixelWithDeclaredDimensionsIsSkipped() {
		let html = """
		<img src="https://example.com/pixel.gif" width="1" height="1">
		<img src="https://example.com/photo.jpg" width="640" height="480">
		"""
		#expect(firstSignificantImage(html) == HTMLImage(urlString: "https://example.com/photo.jpg", width: 640, height: 480))
	}

	@Test func imageWithUndeclaredDimensionsIsAccepted() {
		// Real dimensions are checked at download time.
		let html = #"<img src="https://example.com/photo.jpg">"#
		#expect(firstSignificantImage(html) == HTMLImage(urlString: "https://example.com/photo.jpg", width: nil, height: nil))
	}

	@Test func gravatarIsSkipped() {
		let html = """
		<img src="https://secure.gravatar.com/avatar/0123456789abcdef?s=96&amp;d=identicon" alt="">
		<img src="https://example.com/photo.jpg">
		"""
		#expect(firstSignificantImage(html)?.urlString == "https://example.com/photo.jpg")
	}

	@Test func srcsetIsUsedWhenSrcIsPlaceholder() {
		let html = """
		<img src="data:image/gif;base64,R0lGODlhAQABAAAAACw=" srcset="/a-300.jpg 300w, /a-1024.jpg 1024w, /a-768.jpg 768w" width="1024" height="683">
		"""
		#expect(firstSignificantImage(html)?.urlString == "https://example.com/a-1024.jpg")
	}

	@Test func srcsetIsUsedBeforeSrc() {
		let html = #"<img src="/spacer.gif" srcset="/real-400.jpg 400w, /real-800.jpg 800w">"#
		#expect(firstSignificantImage(html)?.urlString == "https://example.com/real-800.jpg")
	}

	@Test func srcsetUsesNarrowestCandidateWideEnoughForThumbnail() {
		let html = #"<img srcset="/a-768.jpg 768w, /a-2048.jpg 2048w, /a-1536.jpg 1536w, /a-2560.jpg 2560w">"#
		#expect(firstSignificantImage(html)?.urlString == "https://example.com/a-1536.jpg")
	}

	@Test func srcsetDescriptorCanEndWithNewlineOrHaveHeight() {
		let htmlWithNewlines = """
		<img srcset="
			/a-400.jpg 400w,
			/a-800.jpg 800w
		">
		"""
		#expect(firstSignificantImage(htmlWithNewlines)?.urlString == "https://example.com/a-800.jpg")

		let htmlWithHeights = #"<img srcset="/a-400.jpg 400w 300h, /a-800.jpg 800w 600h">"#
		#expect(firstSignificantImage(htmlWithHeights)?.urlString == "https://example.com/a-800.jpg")
	}

	@Test func lazySourceIsUsedWhenSrcIsPlaceholder() {
		let html = """
		<a href=" https://twitter.com/intent/tweet?url=x "><img src="/share/twitter.png"></a>
		<img src="https://s0.wp.com/i/blank.jpg" data-lazy-src="/uploads/photo.jpg" width="640" height="480">
		"""
		#expect(firstSignificantImage(html)?.urlString == "https://example.com/uploads/photo.jpg")
	}

	@Test func lazySrcsetAndOriginalAreUsedWhenSrcIsPlaceholder() {
		let placeholder = "data:image/gif;base64,R0lGODlhAQABAAAAACw="
		#expect(firstSignificantImage(#"<img src="\#(placeholder)" data-srcset="/a-400.jpg 400w, /a-800.jpg 800w">"#)?.urlString == "https://example.com/a-800.jpg")
		#expect(firstSignificantImage(#"<img src="\#(placeholder)" data-lazy-srcset="/b-400.jpg 400w, /b-800.jpg 800w">"#)?.urlString == "https://example.com/b-800.jpg")
		#expect(firstSignificantImage(#"<img src="\#(placeholder)" data-original="/c.jpg">"#)?.urlString == "https://example.com/c.jpg")
	}

	@Test func significantImagesAreFoundUpToMaximumCount() {
		let html = """
		<img src="/a.jpg"><img src="/a.jpg"><img src="/logo.svg"><img src="/b.jpg"><img src="/c.jpg">
		"""
		let images = HTMLImageParser.significantImages(html: html, baseURL: URL(string: "https://example.com/posts/1"), maximumCount: 2)
		#expect(images.map(\.urlString) == ["https://example.com/a.jpg", "https://example.com/b.jpg"])
	}

	@Test func relativeURLsAreResolved() {
		#expect(firstSignificantImage(#"<img src="images/a.jpg">"#)?.urlString == "https://example.com/posts/images/a.jpg")
		#expect(firstSignificantImage(#"<img src="//cdn.example.net/a.jpg">"#)?.urlString == "https://cdn.example.net/a.jpg")
	}

	@Test func relativeURLIsSkippedWithoutBaseURL() {
		let html = #"<img src="/images/a.jpg"><img src="https://example.com/b.jpg">"#
		let images = HTMLImageParser.significantImages(html: html, baseURL: nil, maximumCount: 3)
		#expect(images.map(\.urlString) == ["https://example.com/b.jpg"])
	}

	@Test func dimensionsInPixelsAreParsed() {
		let html = #"<img src="https://example.com/a.jpg" width="50%" height="300px">"#
		#expect(firstSignificantImage(html) == HTMLImage(urlString: "https://example.com/a.jpg", width: nil, height: 300))
	}

	@Test func decorativeURLsAreRejected() {
		#expect(!SignificantImageFilter.isSignificant(urlString: "https://example.com/logo.svg", width: nil, height: nil))
		#expect(!SignificantImageFilter.isSignificant(urlString: "https://s0.wp.com/i/blank.jpg", width: nil, height: nil))
		#expect(!SignificantImageFilter.isSignificant(urlString: "https://pixel.wp.com/b.gif?v=1", width: nil, height: nil))
		#expect(!SignificantImageFilter.isSignificant(urlString: "ftp://example.com/a.jpg", width: nil, height: nil))
		#expect(!SignificantImageFilter.isSignificant(urlString: "https://example.com/banner.jpg", width: 1200, height: 250))
		#expect(!SignificantImageFilter.isSignificant(urlString: "https://example.com/images/spacer.gif", width: nil, height: nil))
		#expect(!SignificantImageFilter.isSignificant(urlString: "https://email.example.net/open/abc123.gif", width: nil, height: nil))
		#expect(!SignificantImageFilter.isSignificant(urlString: "https://email.example.net/wf/open?upn=abc123", width: nil, height: nil))
		#expect(SignificantImageFilter.isSignificant(urlString: "https://cdn.example.com/track/cover.jpg", width: nil, height: nil))
		#expect(SignificantImageFilter.isSignificant(urlString: "https://example.com/2026/open-source-pixel-art.jpg", width: nil, height: nil))
	}
}

// MARK: - Helpers

private func firstSignificantImage(_ html: String) -> HTMLImage? {
	HTMLImageParser.significantImages(html: html, baseURL: URL(string: "https://example.com/posts/1"), maximumCount: 1).first
}
