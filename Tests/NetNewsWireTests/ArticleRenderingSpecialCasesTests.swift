//
//  ArticleRenderingSpecialCasesTests.swift
//  NetNewsWireTests
//
//  Created by Brent Simmons on 2026-07-06.
//

import Foundation
import Testing

@testable import NetNewsWire

@Suite struct ArticleRenderingSpecialCasesTests {

	// <https://github.com/Ranchero-Software/NetNewsWire/issues/4150>

	@Test func redirectAssignmentIsRemoved() {
		let html = "<p>Before</p><script>location.href='https://example.com/full/';</script><p>After</p>"
		let filtered = ArticleRenderingSpecialCases.filterHTMLIfNeeded(baseURL: "https://example.com/post/", html: html)
		#expect(!filtered.contains("location.href"))
		#expect(filtered.contains("<p>Before</p>"))
		#expect(filtered.contains("<p>After</p>"))
	}

	@Test func spacedAssignmentAndWindowLocationRemoved() {
		let html = "<script> window.location.href = 'https://example.com/x/' ;</script>KEEP"
		let filtered = ArticleRenderingSpecialCases.filterHTMLIfNeeded(baseURL: "https://example.com/a/", html: html)
		#expect(!filtered.contains("location.href"))
		#expect(filtered.contains("KEEP"))
	}

	// A read/comparison of location.href is not an assignment — keep it.
	@Test func readsAndComparisonsAreKept() {
		let read = "<script>if (location.href.includes('x')) { doThing(); }</script>"
		let compare = "<script>if (location.href == 'x') { doThing(); }</script>"
		#expect(ArticleRenderingSpecialCases.filterHTMLIfNeeded(baseURL: "https://example.com/a/", html: read) == read)
		#expect(ArticleRenderingSpecialCases.filterHTMLIfNeeded(baseURL: "https://example.com/a/", html: compare) == compare)
	}

	// Fast path: no mention of location.href → returned unchanged.
	@Test func contentWithoutLocationHrefIsUnchanged() {
		let html = "<p>Just an article.</p><script>console.log('hi');</script>"
		#expect(ArticleRenderingSpecialCases.filterHTMLIfNeeded(baseURL: "https://example.com/a/", html: html) == html)
	}

	// MARK: - JavaScript disabled by domain

	@Test func slashdotSubdomainLinkDisablesJavaScript() {
		let link = "https://yro.slashdot.org/story/26/09/18/0023251/will-california-gut-its-net-neutrality-law?utm_source=rss1.0mainlinkanon&utm_medium=feed"
		#expect(ArticleRenderingSpecialCases.shouldDisableJavaScript(urlStrings: [link, nil, nil]))
	}

	@Test func slashdotRootLinkDisablesJavaScript() {
		#expect(ArticleRenderingSpecialCases.shouldDisableJavaScript(urlStrings: ["https://slashdot.org/", nil, nil]))
	}

	@Test func slashdotFeedURLDisablesJavaScriptWhenLinkIsNil() {
		#expect(ArticleRenderingSpecialCases.shouldDisableJavaScript(urlStrings: [nil, "https://rss.slashdot.org/Slashdot/slashdotMain", nil]))
	}

	@Test func otherDomainKeepsJavaScript() {
		#expect(!ArticleRenderingSpecialCases.shouldDisableJavaScript(urlStrings: ["https://example.com/post/", "https://example.com/feed.xml", "https://example.com/"]))
	}

	// The domain must match at a subdomain boundary, not as a bare suffix.
	@Test func similarDomainKeepsJavaScript() {
		#expect(!ArticleRenderingSpecialCases.shouldDisableJavaScript(urlStrings: ["https://notslashdot.org/story/", nil, nil]))
	}

	@Test func allNilURLsKeepJavaScript() {
		#expect(!ArticleRenderingSpecialCases.shouldDisableJavaScript(urlStrings: [nil, nil, nil]))
	}

	// MARK: - Paragraphs separated by returns

	// The first article in the Slashdot feed on 2026-10-02, with each paragraph cut to its first sentence.
	@Test func slashdotArticleBodyGetsParagraphTags() {
		let feedURLString = "https://rss.slashdot.org/Slashdot/slashdotMain"

		let paragraph1 = "An anonymous reader quotes a report from Reuters: A growing number of people think social media manipulates and divides people and harms democracy, Pew Research Center said on Thursday, echoing rising concern and tighter scrutiny across the world."
		let paragraph2 = "Australia has proposed rules to let users opt out of algorithmically recommended feeds, after becoming the first country to ban social media for children under 16."
		let paragraph3 = "People in wealthier countries, including the US, Canada and UK, are more inclined to believe that social media is harming democracy, versus their counterparts in economies with lower gross domestic product per capita -- such as Ghana, Kenya and Nigeria."
		let shareLinks = #"<p><div class="share_submission" style="position:relative;">"# + "\n"
			+ #"<a class="slashpop" href="http://twitter.com/home?status=Social+Media+Harms+Democracy+By+Spreading+Rumors%2C+Survey+Shows%3A+https%3A%2F%2Ftech.slashdot.org%2Fstory%2F26%2F10%2F02%2F0632243%2F%3Futm_source%3Dtwitter%26utm_medium%3Dtwitter"><img src="https://a.fsdn.com/sd/twitter_icon_large.png"></a>"# + "\n"
			+ #"<a class="slashpop" href="http://www.facebook.com/sharer.php?u=https%3A%2F%2Ftech.slashdot.org%2Fstory%2F26%2F10%2F02%2F0632243%2Fsocial-media-harms-democracy-by-spreading-rumors-survey-shows%3Futm_source%3Dslashdot%26utm_medium%3Dfacebook"><img src="https://a.fsdn.com/sd/facebook_icon_large.png"></a>"#
		let readMore = #"</div></p><p><a href="https://tech.slashdot.org/story/26/10/02/0632243/social-media-harms-democracy-by-spreading-rumors-survey-shows?utm_source=rss1.0moreanon&amp;utm_medium=feed">Read more of this story</a> at Slashdot.</p><iframe src="https://slashdot.org/slashdot-it.pl?op=discuss&amp;id=24112882&amp;smallembed=1" style="height: 300px; width: 100%; border: none;"></iframe>"#

		let html = paragraph1 + "\n \n" + paragraph2 + "\n \n" + paragraph3 + shareLinks + "\n\n\n\n" + readMore
		let expected = paragraph1 + "<p>" + paragraph2 + "<p>" + paragraph3 + shareLinks + "<p>" + readMore

		let result = ArticleRenderingSpecialCases.insertParagraphTagsIfNeeded(html, feedURL: feedURLString, homePageURL: nil)
		#expect(result == expected)
	}

	@Test func slashdotHomePageURLGetsParagraphTagsForProxiedFeed() {
		let html = "First paragraph.\n\nSecond paragraph."
		let result = ArticleRenderingSpecialCases.insertParagraphTagsIfNeeded(html, feedURL: "https://feeds.feedburner.com/Slashdot/slashdot", homePageURL: "https://slashdot.org/")
		#expect(result == "First paragraph.<p>Second paragraph.")
	}

	@Test func otherFeedsDontGetParagraphTags() {
		let html = "First paragraph.\n\nSecond paragraph."
		let result = ArticleRenderingSpecialCases.insertParagraphTagsIfNeeded(html, feedURL: "https://example.com/feed.xml", homePageURL: "https://example.com/")
		#expect(result == html)
	}

	// MARK: - Base URL for YouTube articles

	// <https://github.com/Ranchero-Software/NetNewsWire/issues/4860>
	@Test func youtubeArticleGetsNetNewsWireBaseURL() throws {
		let youtubeLink = try #require(URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"))
		#expect(ArticleRenderingSpecialCases.baseURLForRendering(youtubeLink).absoluteString == "https://netnewswire.com/")

		let hackadayLink = try #require(URL(string: "https://hackaday.com/2025/12/01/necroprinting-isnt-as-bad-as-it-sounds/"))
		#expect(ArticleRenderingSpecialCases.baseURLForRendering(hackadayLink) == hackadayLink)
	}
}
