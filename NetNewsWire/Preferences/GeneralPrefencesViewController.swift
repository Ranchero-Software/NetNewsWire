//
//  GeneralPrefencesViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/3/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import RSCore

final class GeneralPreferencesViewController: NSViewController {

	@IBOutlet var defaultRSSReaderPopup: NSPopUpButton!
	static let feedURLScheme = "feed:"
	static let feedsURLScheme = "feeds:"

	override func viewWillAppear() {
		updateRSSReaderPopup()
	}
}

private extension GeneralPreferencesViewController {

	func updateRSSReaderPopup() {
		let rssReaders = fetchRSSReaders()
		print(rssReaders)
	}

	func fetchRSSReaders() -> Set<RSSReader> {
		let defaultRSSReaderBundleID = NSWorkspace.shared.defaultAppBundleID(forURLScheme: GeneralPreferencesViewController.feedURLScheme)
		let rssReaderBundleIDs = NSWorkspace.shared.bundleIDsForApps(forURLScheme: GeneralPreferencesViewController.feedURLScheme)

		var allReaders = Set<RSSReader>()
		if let defaultRSSReaderBundleID = defaultRSSReaderBundleID, let defaultReader = RSSReader(bundleID: defaultRSSReaderBundleID, isDefaultReader: true) {
			allReaders.insert(defaultReader)
		}
		rssReaderBundleIDs.forEach { (bundleID) in
			let isDefault = bundleID == defaultRSSReaderBundleID
			if let reader = RSSReader(bundleID: bundleID, isDefaultReader: isDefault) {
				allReaders.insert(reader)
			}
		}
		return allReaders
	}
}

private final class RSSReader: Hashable {

	let bundleID: String
	let name: String
	let nameMinusAppSuffix: String
	let path: String
	let isDefaultReader: Bool

	init?(bundleID: String, isDefaultReader: Bool) {
		guard let path = NSWorkspace.shared.absolutePathForApplication(withBundleIdentifier: bundleID) else {
			return nil
		}

		self.path = path
		self.bundleID = bundleID
		self.isDefaultReader = isDefaultReader

		let name = (path as NSString).lastPathComponent
		self.name = name
		if name.hasSuffix(".app") {
			self.nameMinusAppSuffix = name.rs_string(byStrippingSuffix: ".app", caseSensitive: false)
		}
		else {
			self.nameMinusAppSuffix = name
		}
	}

	// MARK: - Hashable

	func hash(into hasher: inout Hasher) {
		hasher.combine(bundleID)
	}

	// MARK: - Equatable

	static func ==(lhs: RSSReader, rhs: RSSReader) -> Bool {
		return lhs.bundleID == rhs.bundleID
	}
}
