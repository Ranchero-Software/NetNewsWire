//
//  URLPreparedForOpeningTests.swift
//  RSWebTests
//
//  Created by Brent Simmons on 9/1/26.
//

import Foundation
import Testing
import RSWeb

struct URLPreparedForOpeningTests {

	@Test func allowsWebAndMailSchemes() throws {
		#expect(try url("http://example.com/").preparedForOpeningInBrowser() != nil)
		#expect(try url("https://example.com/").preparedForOpeningInBrowser() != nil)
		#expect(try url("mailto:me@example.com").preparedForOpeningInBrowser() != nil)
	}

#if os(macOS)
	@Test func allowsMagnetScheme() throws {
		#expect(try url("magnet:?xt=urn:btih:c12fe1c06bba254a9dc9f519b335aa7c1367a88a&dn=example").preparedForOpeningInBrowser() != nil)
		#expect(try url("Magnet:?xt=urn:btih:c12fe1c06bba254a9dc9f519b335aa7c1367a88a").preparedForOpeningInBrowser() != nil)
	}
#else
	@Test func blocksMagnetScheme() throws {
		#expect(try url("magnet:?xt=urn:btih:c12fe1c06bba254a9dc9f519b335aa7c1367a88a&dn=example").preparedForOpeningInBrowser() == nil)
	}
#endif

	@Test func blocksOtherSchemes() throws {
		#expect(try url("smb://server/share").preparedForOpeningInBrowser() == nil)
		#expect(try url("file:///etc/passwd").preparedForOpeningInBrowser() == nil)
		#expect(try url("ftp://example.com/x").preparedForOpeningInBrowser() == nil)
		#expect(try url("javascript:alert(1)").preparedForOpeningInBrowser() == nil)
		#expect(try url("data:text/html,x").preparedForOpeningInBrowser() == nil)
		#expect(try url("tel:+15555555555").preparedForOpeningInBrowser() == nil)
	}

	@Test func schemeMatchIsCaseInsensitive() throws {
		#expect(try url("HTTPS://example.com/").preparedForOpeningInBrowser() != nil)
		#expect(try url("MailTo:me@example.com").preparedForOpeningInBrowser() != nil)
	}

	@Test func allowedURLPassesThroughUnchanged() throws {
		let prepared = try #require(url("http://example.com/path?q=1").preparedForOpeningInBrowser())
		#expect(prepared.absoluteString == "http://example.com/path?q=1")
	}

	@Test func externalApplicationURLsPassThroughUnchanged() throws {
		for string in [
			"octal://item?id=12345678",
			"OCTAL://item?id=1",
			"netnewswire://theme/add?url=https://example.com/t.nnwtheme",
			"netnewswire://theme/add",
			"feed:https://example.com/rss.xml",
			"feeds:https://example.com/rss.xml"
		] {
			let prepared = try #require(url(string).preparedForOpeningInExternalApplication())
			#expect(prepared.absoluteString == string)
		}
	}

	@Test func blocksNonExternalApplicationURLs() throws {
		for string in [
			"http://example.com/", "https://example.com/", "mailto:me@example.com", "tel:+15555555555",
			"javascript:alert(1)", "JAVASCRIPT:alert(1)", "data:text/html,x", "file:///etc/passwd",
			"about:blank", "blob:https://example.com/id", "vbscript:msgbox(1)", "relative/path"
		] {
			#expect(try url(string).preparedForOpeningInExternalApplication() == nil)
		}
	}

	@Test func excludesInternalSchemesCaseInsensitively() throws {
		let excludedSchemes: Set<String> = ["nnwImageIcon", "nnwArticleImage"]
		for string in ["nnwImageIcon:abc", "nnwArticleImage:abc", "NNWIMAGEICON:abc", "NNWARTICLEIMAGE:abc"] {
			let original = try url(string)
			#expect(original.preparedForOpeningInExternalApplication(excluding: excludedSchemes) == nil)
			#expect(original.preparedForOpeningInExternalApplication() != nil)
		}
	}

	private func url(_ string: String) throws -> URL {
		try #require(URL(string: string))
	}
}
