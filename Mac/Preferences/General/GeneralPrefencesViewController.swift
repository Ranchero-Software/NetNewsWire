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
	private var rssReaderInfo = RSSReaderInfo()

	public override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
		super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
		commonInit()
	}

	public required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}

	override func viewWillAppear() {
		super.viewWillAppear()
		updateUI()
	}

	// MARK: - Notifications

	@objc func applicationWillBecomeActive(_ note: Notification) {
		updateUI()
	}

	// MARK: - Actions

	@IBAction func rssReaderPopupDidChangeValue(_ sender: Any?) {
		guard let menuItem = defaultRSSReaderPopup.selectedItem else {
			return
		}
		guard let bundleID = menuItem.representedObject as? String else {
			return
		}
		registerAppWithBundleID(bundleID)
		updateUI()
	}
}

// MARK: - Private

private extension GeneralPreferencesViewController {

	func commonInit() {
		NotificationCenter.default.addObserver(self, selector: #selector(applicationWillBecomeActive(_:)), name: NSApplication.willBecomeActiveNotification, object: nil)
	}

	func updateUI() {
		rssReaderInfo = RSSReaderInfo()
		updateRSSReaderPopup()
	}

	func updateRSSReaderPopup() {
		// Top item should always be: NetNewsWire (this app)
		// Additional items should be sorted alphabetically.
		// Any older versions of NetNewsWire should be listed as: NetNewsWire (old version)

		let menu = NSMenu(title: "RSS Readers")

		let netNewsWireBundleID = Bundle.main.bundleIdentifier!
		let thisAppParentheticalComment = NSLocalizedString("(this app)", comment: "Preferences default RSS Reader popup")
		let thisAppName = "NetNewsWire \(thisAppParentheticalComment)"
		let netNewsWireMenuItem = NSMenuItem(title: thisAppName, action: nil, keyEquivalent: "")
		netNewsWireMenuItem.representedObject = netNewsWireBundleID
		menu.addItem(netNewsWireMenuItem)

		let readersToList = rssReaderInfo.rssReaders.filter { $0.bundleID != netNewsWireBundleID }
		let sortedReaders = readersToList.sorted { (reader1, reader2) -> Bool in
			return reader1.nameMinusAppSuffix.localizedStandardCompare(reader2.nameMinusAppSuffix) == .orderedAscending
		}

		let oldVersionParentheticalComment = NSLocalizedString("(old version)", comment: "Preferences default RSS Reader popup")
		for rssReader in sortedReaders {
			var appName = rssReader.nameMinusAppSuffix
			if appName.contains("NetNewsWire") {
				appName = "\(appName) \(oldVersionParentheticalComment)"
			}
			let menuItem = NSMenuItem(title: appName, action: nil, keyEquivalent: "")
			menuItem.representedObject = rssReader.bundleID
			menu.addItem(menuItem)
		}

		defaultRSSReaderPopup.menu = menu

		func insertAndSelectNoneMenuItem() {
			let noneTitle = NSLocalizedString("None", comment: "Preferences default RSS Reader popup")
			let menuItem = NSMenuItem(title: noneTitle, action: nil, keyEquivalent: "")
			defaultRSSReaderPopup.menu!.insertItem(menuItem, at: 0)
			defaultRSSReaderPopup.selectItem(at: 0)
		}

		guard let defaultRSSReaderBundleID = rssReaderInfo.defaultRSSReaderBundleID else {
			insertAndSelectNoneMenuItem()
			return
		}

		for menuItem in defaultRSSReaderPopup.menu!.items {
			guard let bundleID = menuItem.representedObject as? String else {
				continue
			}
			if bundleID == defaultRSSReaderBundleID {
				defaultRSSReaderPopup.select(menuItem)
				return
			}
		}

		insertAndSelectNoneMenuItem()
	}

	func registerAppWithBundleID(_ bundleID: String) {
		NSWorkspace.shared.setDefaultAppBundleID(forURLScheme: "feed", to: bundleID)
		NSWorkspace.shared.setDefaultAppBundleID(forURLScheme: "feeds", to: bundleID)
	}
}


// MARK: - RSSReaderInfo

private struct RSSReaderInfo {

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

private struct RSSReader: Hashable {

	let bundleID: String
	let name: String
	let nameMinusAppSuffix: String
	let path: String

	init?(bundleID: String) {
		guard let path = NSWorkspace.shared.absolutePathForApplication(withBundleIdentifier: bundleID) else {
			return nil
		}

		self.path = path
		self.bundleID = bundleID

		let name = (path as NSString).lastPathComponent
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
