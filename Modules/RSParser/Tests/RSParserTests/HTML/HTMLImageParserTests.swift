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
			let urlString = HTMLImageParser.significantImageURLStrings(html: html, baseURL: URL(string: item.url ?? ""), maximumCount: 1).first
			if let urlString {
				foundImageCount += 1
				#expect(!urlString.contains("s.w.org"))
			}
			if item.url == "https://www.natashatherobot.com/url-apple-wallet-passkit-pass/" {
				// The first image is 503×88, too wide to stand for the article.
				#expect(urlString == "https://www.natashatherobot.com/wp-content/uploads/Screen-Shot-2017-07-07-at-12.35.13-PM.png")
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
		#expect(firstSignificantImageURLString(html) == nil)
	}

	@Test func hiddenImagesAreSkipped() {
		let html = """
		<img src="https://t.example.com/o/abc" style="display:none">
		<img src="https://t.example.com/o/def" style="DISPLAY: none !important">
		<img src="https://t.example.com/o/ghi" hidden>
		<img src="https://t.example.com/o/jkl" style="width:1px;height:1px">
		<img src="/real.jpg" style="max-width:1px;width:100%">
		"""
		#expect(firstSignificantImageURLString(html) == "https://example.com/real.jpg")
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
		#expect(firstSignificantImageURLString(html) == "https://example.com/photo.jpg")
	}

	@Test func trackingPixelWithDeclaredDimensionsIsSkipped() {
		let html = """
		<img src="https://example.com/pixel.gif" width="1" height="1">
		<img src="https://example.com/photo.jpg" width="640" height="480">
		"""
		#expect(firstSignificantImageURLString(html) == "https://example.com/photo.jpg")
	}

	@Test func imageWithUndeclaredDimensionsIsAccepted() {
		// Real dimensions are checked at download time.
		let html = #"<img src="https://example.com/photo.jpg">"#
		#expect(firstSignificantImageURLString(html) == "https://example.com/photo.jpg")
	}

	@Test func gravatarIsSkipped() {
		let html = """
		<img src="https://secure.gravatar.com/avatar/0123456789abcdef?s=96&amp;d=identicon" alt="">
		<img src="https://example.com/photo.jpg">
		"""
		#expect(firstSignificantImageURLString(html) == "https://example.com/photo.jpg")
	}

	@Test func srcsetIsUsedWhenSrcIsPlaceholder() {
		let html = """
		<img src="data:image/gif;base64,R0lGODlhAQABAAAAACw=" srcset="/a-300.jpg 300w, /a-1024.jpg 1024w, /a-768.jpg 768w" width="1024" height="683">
		"""
		#expect(firstSignificantImageURLString(html) == "https://example.com/a-1024.jpg")
	}

	@Test func srcsetIsUsedBeforeSrc() {
		let html = #"<img src="/spacer.gif" srcset="/real-400.jpg 400w, /real-800.jpg 800w">"#
		#expect(firstSignificantImageURLString(html) == "https://example.com/real-800.jpg")
	}

	@Test func srcsetUsesNarrowestCandidateWideEnoughForThumbnail() {
		let html = #"<img srcset="/a-768.jpg 768w, /a-2048.jpg 2048w, /a-1536.jpg 1536w, /a-2560.jpg 2560w">"#
		#expect(firstSignificantImageURLString(html) == "https://example.com/a-1536.jpg")
	}

	@Test func srcsetDescriptorCanEndWithNewlineOrHaveHeight() {
		let htmlWithNewlines = """
		<img srcset="
			/a-400.jpg 400w,
			/a-800.jpg 800w
		">
		"""
		#expect(firstSignificantImageURLString(htmlWithNewlines) == "https://example.com/a-800.jpg")

		let htmlWithHeights = #"<img srcset="/a-400.jpg 400w 300h, /a-800.jpg 800w 600h">"#
		#expect(firstSignificantImageURLString(htmlWithHeights) == "https://example.com/a-800.jpg")
	}

	@Test func lazySourceIsUsedWhenSrcIsPlaceholder() {
		let html = """
		<a href=" https://twitter.com/intent/tweet?url=x "><img src="/share/twitter.png"></a>
		<img src="https://s0.wp.com/i/blank.jpg" data-lazy-src="/uploads/photo.jpg" width="640" height="480">
		"""
		#expect(firstSignificantImageURLString(html) == "https://example.com/uploads/photo.jpg")
	}

	@Test func lazySrcsetAndOriginalAreUsedWhenSrcIsPlaceholder() {
		let placeholder = "data:image/gif;base64,R0lGODlhAQABAAAAACw="
		#expect(firstSignificantImageURLString(#"<img src="\#(placeholder)" data-srcset="/a-400.jpg 400w, /a-800.jpg 800w">"#) == "https://example.com/a-800.jpg")
		#expect(firstSignificantImageURLString(#"<img src="\#(placeholder)" data-lazy-srcset="/b-400.jpg 400w, /b-800.jpg 800w">"#) == "https://example.com/b-800.jpg")
		#expect(firstSignificantImageURLString(#"<img src="\#(placeholder)" data-original="/c.jpg">"#) == "https://example.com/c.jpg")
	}

	@Test func significantImageURLStringsAreFoundUpToMaximumCount() {
		let html = """
		<img src="/a.jpg"><img src="/a.jpg"><img src="/logo.svg"><img src="/b.jpg"><img src="/c.jpg">
		"""
		let urlStrings = HTMLImageParser.significantImageURLStrings(html: html, baseURL: URL(string: "https://example.com/posts/1"), maximumCount: 2)
		#expect(urlStrings == ["https://example.com/a.jpg", "https://example.com/b.jpg"])
	}

	@Test func relativeURLsAreResolved() {
		#expect(firstSignificantImageURLString(#"<img src="images/a.jpg">"#) == "https://example.com/posts/images/a.jpg")
		#expect(firstSignificantImageURLString(#"<img src="//cdn.example.net/a.jpg">"#) == "https://cdn.example.net/a.jpg")
	}

	@Test func relativeURLIsSkippedWithoutBaseURL() {
		let html = #"<img src="/images/a.jpg"><img src="https://example.com/b.jpg">"#
		let urlStrings = HTMLImageParser.significantImageURLStrings(html: html, baseURL: nil, maximumCount: 3)
		#expect(urlStrings == ["https://example.com/b.jpg"])
	}

	@Test func dimensionsInPixelsAreParsed() {
		// The 1px height is too small. The 50% width isn’t in pixels, so it doesn’t count toward the aspect ratio.
		let html = #"<img src="https://example.com/a.jpg" width="300" height="1px"><img src="https://example.com/b.jpg" width="50%" height="300px">"#
		#expect(firstSignificantImageURLString(html) == "https://example.com/b.jpg")
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

private func firstSignificantImageURLString(_ html: String) -> String? {
	HTMLImageParser.significantImageURLStrings(html: html, baseURL: URL(string: "https://example.com/posts/1"), maximumCount: 1).first
}
