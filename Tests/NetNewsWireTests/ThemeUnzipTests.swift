//
//  ThemeUnzipTests.swift
//  NetNewsWireTests
//
//  Created by Brent Simmons on 2026-08-31.
//

import Foundation
import Testing

@testable import NetNewsWire

@Suite struct ThemeUnzipTests {

	@Test func normalThemeArchiveExtracts() throws {
		let root = try makeTemporaryDirectory()
		defer {
			try? FileManager.default.removeItem(at: root)
		}

		let zipURL = try writeZipFile(Self.benignThemeZipBase64, to: root)
		let destination = root.appendingPathComponent("extract")

		let themeURL = try ArticleThemeDownloader.shared.unzipTheme(at: zipURL, to: destination)

		#expect(themeURL.lastPathComponent == "Good Theme.nnwtheme")
		#expect(FileManager.default.fileExists(atPath: themeURL.appendingPathComponent("Info.plist").path))
	}

	@Test func pathTraversalArchiveIsRejectedAndWritesNothingOutsideDestination() throws {
		let root = try makeTemporaryDirectory()
		defer {
			try? FileManager.default.removeItem(at: root)
		}

		let zipURL = try writeZipFile(Self.pathTraversalZipBase64, to: root)
		let destination = root.appendingPathComponent("extract")

		// The archive's `../escaped.txt` entry would resolve to `root/escaped.txt`, one level
		// above the destination. It must never be written.
		let escapeTarget = root.appendingPathComponent("escaped.txt")

		#expect(throws: (any Error).self) {
			_ = try ArticleThemeDownloader.shared.unzipTheme(at: zipURL, to: destination)
		}
		#expect(!FileManager.default.fileExists(atPath: escapeTarget.path))
	}
}

// MARK: - Helpers

private extension ThemeUnzipTests {

	func makeTemporaryDirectory() throws -> URL {
		let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
		return url
	}

	func writeZipFile(_ base64: String, to directory: URL) throws -> URL {
		guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else {
			throw CocoaError(.fileReadCorruptFile)
		}
		let url = directory.appendingPathComponent("\(UUID().uuidString).zip")
		try data.write(to: url)
		return url
	}
}

// MARK: - Fixtures

// benignThemeZip:   Good Theme.nnwtheme/{Info.plist, stylesheet.css, template.html}
// pathTraversalZip: Good Theme.nnwtheme/Info.plist, then ../escaped.txt
private extension ThemeUnzipTests {

	static let benignThemeZipBase64 = """
	UEsDBBQAAAAAAGejH10lf2Ft4wAAAOMAAAAeAAAAR29vZCBUaGVtZS5ubnd0aGVtZS9JbmZvLnBsaXN0PD94bWwgdmVyc2lvbj0i
	MS4wIiBlbmNvZGluZz0iVVRGLTgiPz4KPCFET0NUWVBFIHBsaXN0IFBVQkxJQyAiLS8vQXBwbGUvL0RURCBQTElTVCAxLjAvL0VO
	IiAiaHR0cDovL3d3dy5hcHBsZS5jb20vRFREcy9Qcm9wZXJ0eUxpc3QtMS4wLmR0ZCI+CjxwbGlzdCB2ZXJzaW9uPSIxLjAiPjxk
	aWN0PjxrZXk+bmFtZTwva2V5PjxzdHJpbmc+R29vZCBUaGVtZTwvc3RyaW5nPjwvZGljdD48L3BsaXN0PgpQSwMEFAAAAAAAZ6Mf
	XVokqGUXAAAAFwAAACIAAABHb29kIFRoZW1lLm5ud3RoZW1lL3N0eWxlc2hlZXQuY3NzYm9keSB7IGNvbG9yOiBibGFjazsgfQpQ
	SwMEFAAAAAAAZ6MfXZN1YIIjAAAAIwAAACEAAABHb29kIFRoZW1lLm5ud3RoZW1lL3RlbXBsYXRlLmh0bWw8aHRtbD48Ym9keT5b
	W2JvZHldXTwvYm9keT48L2h0bWw+ClBLAQIUAxQAAAAAAGejH10lf2Ft4wAAAOMAAAAeAAAAAAAAAAAAAACAAQAAAABHb29kIFRo
	ZW1lLm5ud3RoZW1lL0luZm8ucGxpc3RQSwECFAMUAAAAAABnox9dWiSoZRcAAAAXAAAAIgAAAAAAAAAAAAAAgAEfAQAAR29vZCBU
	aGVtZS5ubnd0aGVtZS9zdHlsZXNoZWV0LmNzc1BLAQIUAxQAAAAAAGejH12TdWCCIwAAACMAAAAhAAAAAAAAAAAAAACAAXYBAABH
	b29kIFRoZW1lLm5ud3RoZW1lL3RlbXBsYXRlLmh0bWxQSwUGAAAAAAMAAwDrAAAA2AEAAAAA
	"""

	static let pathTraversalZipBase64 = """
	UEsDBBQAAAAAAA2mH10lf2Ft4wAAAOMAAAAeAAAAR29vZCBUaGVtZS5ubnd0aGVtZS9JbmZvLnBsaXN0PD94bWwgdmVyc2lvbj0i
	MS4wIiBlbmNvZGluZz0iVVRGLTgiPz4KPCFET0NUWVBFIHBsaXN0IFBVQkxJQyAiLS8vQXBwbGUvL0RURCBQTElTVCAxLjAvL0VO
	IiAiaHR0cDovL3d3dy5hcHBsZS5jb20vRFREcy9Qcm9wZXJ0eUxpc3QtMS4wLmR0ZCI+CjxwbGlzdCB2ZXJzaW9uPSIxLjAiPjxk
	aWN0PjxrZXk+bmFtZTwva2V5PjxzdHJpbmc+R29vZCBUaGVtZTwvc3RyaW5nPjwvZGljdD48L3BsaXN0PgpQSwMEFAAAAAAADaYf
	XVsM+JIHAAAABwAAAA4AAAAuLi9lc2NhcGVkLnR4dGVzY2FwZWRQSwECFAMUAAAAAAANph9dJX9hbeMAAADjAAAAHgAAAAAAAAAA
	AAAAgAEAAAAAR29vZCBUaGVtZS5ubnd0aGVtZS9JbmZvLnBsaXN0UEsBAhQDFAAAAAAADaYfXVsM+JIHAAAABwAAAA4AAAAAAAAA
	AAAAAIABHwEAAC4uL2VzY2FwZWQudHh0UEsFBgAAAAACAAIAiAAAAFIBAAAAAA==
	"""
}
