//
//  FaviconCandidatesTests.swift
//  ImagesTests
//
//  Created by Dave Marquard on 9/7/26.
//

import Foundation
import Testing
import HTMLMetadata
@testable import Images

struct FaviconCandidatesTests {

	private static let homePageURL = "https://example.com/blog"
	private static let defaultFaviconURL = "https://example.com/favicon.ico"

	private func candidates(_ favicons: [HTMLMetadataRecord.Favicon]?, metadataIsUnavailable: Bool = false) -> FaviconDownloader.FaviconCandidates? {
		FaviconDownloader.faviconCandidates(homePageURL: Self.homePageURL, favicons: favicons, metadataIsUnavailable: metadataIsUnavailable)
	}

	// MARK: - Reading the page

	@Test func declaredFaviconComesBeforeTheDefault() {
		let favicon = HTMLMetadataRecord.Favicon(type: nil, urlString: "https://example.com/icon.png")
		let result = candidates([favicon])

		#expect(result?.urls == ["https://example.com/icon.png", Self.defaultFaviconURL])
		#expect(result?.onlyDefaultFaviconURL == false)
	}

	@Test func pageDeclaringNothingFallsBackToTheDefault() {
		let result = candidates([])

		#expect(result?.urls == [Self.defaultFaviconURL])
		#expect(result?.onlyDefaultFaviconURL == true)
	}

	// MARK: - Unusable favicons

	@Test(arguments: [
		HTMLMetadataRecord.Favicon(type: nil, urlString: "https://example.com/icon.svg"),
		HTMLMetadataRecord.Favicon(type: "image/svg+xml", urlString: "https://example.com/icon"),
		HTMLMetadataRecord.Favicon(type: nil, urlString: "data:image/png;base64,iVBORw0KGgo="),
		HTMLMetadataRecord.Favicon(type: nil, urlString: nil)
	])
	func unusableFaviconLeavesOnlyTheDefault(_ favicon: HTMLMetadataRecord.Favicon) {
		let result = candidates([favicon])

		#expect(result?.urls == [Self.defaultFaviconURL])
		// The page was read and named nothing we can use, so failing the default is an answer.
		#expect(result?.onlyDefaultFaviconURL == true)
	}

	/// Hacker News declares only y18.svg, so favicon.ico is the one thing left to try.
	@Test func siteDeclaringOnlySVGStillGetsItsFaviconICO() {
		let svg = HTMLMetadataRecord.Favicon(type: nil, urlString: "https://news.ycombinator.com/y18.svg")
		let result = FaviconDownloader.faviconCandidates(homePageURL: "https://news.ycombinator.com/bestcomments",
														favicons: [svg], metadataIsUnavailable: false)

		#expect(result?.urls == ["https://news.ycombinator.com/favicon.ico"])
	}

	// MARK: - Without the page

	@Test func metadataStillDownloadingProducesNoCandidates() {
		// Guessing now would cache favicon.ico before we ever see what the page declares.
		#expect(candidates(nil, metadataIsUnavailable: false) == nil)
	}

	@Test func metadataThatIsntComingStillTriesTheDefault() {
		let result = candidates(nil, metadataIsUnavailable: true)

		#expect(result?.urls == [Self.defaultFaviconURL])
		// We never read the page, so exhausting this must not record “no favicon”.
		#expect(result?.onlyDefaultFaviconURL == false)
	}

	// MARK: - Default favicon URL

	@Test func defaultFaviconURLIsTheSiteRoot() throws {
		let url = try #require(URL(string: "HTTPS://Example.COM/deep/path?q=1"))

		#expect(FaviconDownloader.defaultFaviconURL(for: url) == "https://example.com/favicon.ico")
	}

	@Test func urlWithoutAHostHasNoDefaultFaviconURL() throws {
		let url = try #require(URL(string: "file:///tmp/page.html"))

		#expect(FaviconDownloader.defaultFaviconURL(for: url) == nil)
	}

	@Test func hostlessHomePageKeepsOnlyItsDeclaredFavicons() {
		let favicon = HTMLMetadataRecord.Favicon(type: nil, urlString: "https://example.com/icon.png")
		let result = FaviconDownloader.faviconCandidates(homePageURL: "file:///tmp/page.html",
														favicons: [favicon], metadataIsUnavailable: false)

		#expect(result?.urls == ["https://example.com/icon.png"])
		#expect(result?.onlyDefaultFaviconURL == false)
	}
}
