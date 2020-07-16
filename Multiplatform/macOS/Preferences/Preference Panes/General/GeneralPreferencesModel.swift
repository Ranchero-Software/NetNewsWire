//
//  GeneralPreferencesModel.swift
//  Multiplatform macOS
//
//  Created by Stuart Breckenridge on 12/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation



class GeneralPreferencesModel: ObservableObject {
	
	@Published var rssReaders = [RSSReader]()
	@Published var readerSelection: Int = 0 {
		willSet {
			if newValue != readerSelection {
				registerAppWithBundleID(rssReaders[newValue].bundleID)
			}
		}
	}
	
	private let readerInfo = RSSReaderInfo()
	
	init() {
		prepareRSSReaders()
	}
	
}

// MARK:- RSS Readers

private extension GeneralPreferencesModel {
	
	func prepareRSSReaders() {
		
		// Populate rssReaders
		var thisApp = RSSReader(bundleID: Bundle.main.bundleIdentifier!)
		thisApp?.nameMinusAppSuffix.append(" (this app—multiplatform)")
		
		let otherRSSReaders = readerInfo.rssReaders.filter { $0.bundleID != Bundle.main.bundleIdentifier! }.sorted(by: { $0.nameMinusAppSuffix < $1.nameMinusAppSuffix })
		rssReaders.append(thisApp!)
		rssReaders.append(contentsOf: otherRSSReaders)
		
		if readerInfo.defaultRSSReaderBundleID != nil {
			let defaultReader = rssReaders.filter({ $0.bundleID == readerInfo.defaultRSSReaderBundleID })
			if defaultReader.count == 1 {
				let reader = defaultReader[0]
				readerSelection = rssReaders.firstIndex(of: reader)!
			}
		}
	}
	
	func registerAppWithBundleID(_ bundleID: String) {
		NSWorkspace.shared.setDefaultAppBundleID(forURLScheme: "feed", to: bundleID)
		NSWorkspace.shared.setDefaultAppBundleID(forURLScheme: "feeds", to: bundleID)
	}
	
}


// MARK: - RSSReaderInfo

struct RSSReaderInfo {

	var defaultRSSReaderBundleID: String? {
		NSWorkspace.shared.defaultAppBundleID(forURLScheme: RSSReaderInfo.feedURLScheme)
	}
	let rssReaders: Set<RSSReader>
	static let feedURLScheme = "feed:"

	init() {
		self.rssReaders = RSSReaderInfo.fetchRSSReaders()
	}

	static func fetchRSSReaders() -> Set<RSSReader> {
		let rssReaderBundleIDs = NSWorkspace.shared.bundleIDsForApps(forURLScheme: feedURLScheme)

		var rssReaders = Set<RSSReader>()
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
	var nameMinusAppSuffix: String
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
