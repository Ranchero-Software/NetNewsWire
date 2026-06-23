//
//  MacWebBrowserTests.swift
//  RSWebTests
//
//  Created by Brent Simmons on 4/27/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

#if os(macOS)
import Testing
@testable import RSWeb

@MainActor @Suite struct MacWebBrowserTests {

	// MARK: - Boot-volume paths

	@Test func rootApplications() {
		let result = MacWebBrowser.displayPath(forCanonicalParentPath: "/Applications")
		#expect(result == "/Applications")
	}

	@Test func homePathShownAsAbsolute() {
		let result = MacWebBrowser.displayPath(forCanonicalParentPath: "/Users/brent/Applications")
		#expect(result == "/Users/brent/Applications")
	}

	@Test func rootPathOutsideHomeIsLeftAbsolute() {
		let result = MacWebBrowser.displayPath(forCanonicalParentPath: "/Library/Internet Plug-Ins")
		#expect(result == "/Library/Internet Plug-Ins")
	}

	@Test func deepRootPathIsTruncated() {
		let result = MacWebBrowser.displayPath(forCanonicalParentPath: "/some/deep/random/path/structure")
		#expect(result == "/some/…/structure")
	}

	// MARK: - Off-root volume paths
	// These reproduce the canonical paths observed in real-world logs from a
	// machine where /Volumes/Data was a firmlink alias for the data partition
	// of a non-boot OS install named "Macintosh HD".

	@Test func volumeApplications() {
		let result = MacWebBrowser.displayPath(forCanonicalParentPath: "/Volumes/Macintosh HD/Applications")
		#expect(result == "/Macintosh HD/Applications")
	}

	@Test func volumeUserApplications() {
		// 3 inside parts → still shown in full.
		let result = MacWebBrowser.displayPath(forCanonicalParentPath: "/Volumes/Macintosh HD/Users/brent/Applications")
		#expect(result == "/Macintosh HD/Users/brent/Applications")
	}

	@Test func volumeRoot() {
		let result = MacWebBrowser.displayPath(forCanonicalParentPath: "/Volumes/MyDrive")
		#expect(result == "/MyDrive")
	}

	@Test func volumeDeepPathIsTruncated() {
		// 4 inside parts → middle-truncate, preserving volume name and trailing.
		let result = MacWebBrowser.displayPath(forCanonicalParentPath: "/Volumes/MyDrive/A/B/C/D")
		#expect(result == "/MyDrive/…/D")
	}

	@Test func volumeNameWithSpacesPreserved() {
		let result = MacWebBrowser.displayPath(forCanonicalParentPath: "/Volumes/External Drive/Apps")
		#expect(result == "/External Drive/Apps")
	}
}
#endif
