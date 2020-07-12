//
//  MacPreferencesModel.swift
//  Multiplatform macOS
//
//  Created by Stuart Breckenridge on 12/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation

enum PreferencePane: Int, CaseIterable {
	case general = 0
	case accounts = 1
	case advanced = 2
	
	var description: String {
		switch self {
		case .general:
			return "General"
		case .accounts:
			return "Accounts"
		case .advanced:
			return "Advanced"
		}
	}
}

class MacPreferencesModel: ObservableObject {
	
	@Published var currentPreferencePane: PreferencePane = PreferencePane.general
	@Published var rssReaders = Array(RSSReaderInfo.fetchRSSReaders(nil)) 
	@Published var rssReaderSelection: Set<RSSReader> = RSSReaderInfo.fetchRSSReaders(nil)
	
}

// MARK:- RSS Readers

private extension MacPreferencesModel {
	
	func prepareRSSReaders() {
		// Top item should always be: NetNewsWire (this app)
		// Additional items should be sorted alphabetically.
		// Any older versions of NetNewsWire should be listed as: NetNewsWire (old version)
		
		
		
		
		
	}
	
	func registerAppWithBundleID(_ bundleID: String) {
		NSWorkspace.shared.setDefaultAppBundleID(forURLScheme: "feed", to: bundleID)
		NSWorkspace.shared.setDefaultAppBundleID(forURLScheme: "feeds", to: bundleID)
		objectWillChange.send()
	}
	
}


// MARK: - RSSReaderInfo

struct RSSReaderInfo {

	let defaultRSSReaderBundleID: String?
	let rssReaders: Set<RSSReader>
	static let feedURLScheme = "feed:"

	init() {
		let defaultRSSReaderBundleID = NSWorkspace.shared.defaultAppBundleID(forURLScheme: RSSReaderInfo.feedURLScheme)
		self.defaultRSSReaderBundleID = defaultRSSReaderBundleID
		self.rssReaders = RSSReaderInfo.fetchRSSReaders(defaultRSSReaderBundleID)
	}

	static func fetchRSSReaders(_ defaultRSSReaderBundleID: String?) -> Set<RSSReader> {
		let rssReaderBundleIDs = NSWorkspace.shared.bundleIDsForApps(forURLScheme: feedURLScheme)

		var rssReaders = Set<RSSReader>()
		if let defaultRSSReaderBundleID = defaultRSSReaderBundleID, let defaultReader = RSSReader(bundleID: defaultRSSReaderBundleID) {
			rssReaders.insert(defaultReader)
		}
		rssReaderBundleIDs.forEach { (bundleID) in
			if let reader = RSSReader(bundleID: bundleID) {
				rssReaders.insert(reader)
			}
		}
		return rssReaders
	}
}


// MARK: - RSSReader

struct RSSReader: Hashable {

	let bundleID: String
	let name: String
	let nameMinusAppSuffix: String
	let path: String

	init?(bundleID: String) {
		guard let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
			return nil
		}

		self.path = path.path
		self.bundleID = bundleID

		let name = (self.path as NSString).lastPathComponent
		self.name = name
		if name.hasSuffix(".app") {
			self.nameMinusAppSuffix = name.stripping(suffix: ".app")
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
