//
//  GeneralPrefencesViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/3/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import RSCore
import RSWeb
import UserNotifications

final class GeneralPreferencesViewController: NSViewController {

	private var userNotificationSettings: UNNotificationSettings?

	@IBOutlet var defaultRSSReaderPopup: NSPopUpButton!
	@IBOutlet var defaultBrowserPopup: NSPopUpButton!
	@IBOutlet weak var showUnreadCountCheckbox: NSButton!
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
		updateNotificationSettings()
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

	@IBAction func browserPopUpDidChangeValue(_ sender: Any?) {
		guard let menuItem = defaultBrowserPopup.selectedItem else {
			return
		}
		let bundleID = menuItem.representedObject as? String
		AppDefaults.shared.defaultBrowserID = bundleID
		updateUI()
	}

    
    @IBAction func toggleShowingUnreadCount(_ sender: Any) {
        guard let checkbox = sender as? NSButton else { return }

		guard userNotificationSettings != nil else {
			DispatchQueue.main.async {
				self.showUnreadCountCheckbox.setNextState()
			}
			return
		}

		UNUserNotificationCenter.current().getNotificationSettings { (settings) in
			self.updateNotificationSettings()

			if settings.authorizationStatus == .denied {
				DispatchQueue.main.async {
					self.showUnreadCountCheckbox.setNextState()
					self.showNotificationsDeniedError()
				}
			} else if settings.authorizationStatus == .authorized {
				DispatchQueue.main.async {
					AppDefaults.shared.hideDockUnreadCount = (checkbox.state.rawValue == 0)
				}
			} else {
				UNUserNotificationCenter.current().requestAuthorization(options: [.badge]) { (granted, error) in
					self.updateNotificationSettings()
					if granted {
						DispatchQueue.main.async {
							AppDefaults.shared.hideDockUnreadCount = checkbox.state.rawValue == 0
							NSApplication.shared.registerForRemoteNotifications()
						}
					} else {
						DispatchQueue.main.async {
							self.showUnreadCountCheckbox.setNextState()
						}
					}
				}
			}
		}
    }
}

// MARK: - Private

private extension GeneralPreferencesViewController {

	func commonInit() {
		NotificationCenter.default.addObserver(self, selector: #selector(applicationWillBecomeActive(_:)), name: NSApplication.willBecomeActiveNotification, object: nil)
	}

	func updateUI() {
		rssReaderInfo = RSSReaderInfo()
		updateBrowserPopup()
		updateRSSReaderPopup()
        updateHideUnreadCountCheckbox()
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

	func updateBrowserPopup() {
		let menu = defaultBrowserPopup.menu!
		let allBrowsers = MacWebBrowser.sortedBrowsers()

		menu.removeAllItems()

		let defaultBrowser = MacWebBrowser.default

		let defaultBrowserFormat = NSLocalizedString("System Default (%@)", comment: "Default browser item title format")
		let defaultBrowserTitle = String(format: defaultBrowserFormat, defaultBrowser.name!)
		let item = NSMenuItem(title: defaultBrowserTitle, action: nil, keyEquivalent: "")
		let icon = defaultBrowser.icon!
		icon.size = NSSize(width: 16.0, height: 16.0)
		item.image = icon

		menu.addItem(item)
		menu.addItem(NSMenuItem.separator())

		for browser in allBrowsers {
			guard let name = browser.name else { continue }

			let item = NSMenuItem(title: name, action: nil, keyEquivalent: "")
			item.representedObject = browser.bundleIdentifier

			let icon = browser.icon ?? NSWorkspace.shared.icon(forFileType: kUTTypeApplicationBundle as String)
			icon.size = NSSize(width: 16.0, height: 16.0)
			item.image = browser.icon
			menu.addItem(item)
		}

		defaultBrowserPopup.selectItem(at: defaultBrowserPopup.indexOfItem(withRepresentedObject: AppDefaults.shared.defaultBrowserID))
	}

    func updateHideUnreadCountCheckbox() {
        showUnreadCountCheckbox.state = AppDefaults.shared.hideDockUnreadCount ? .off : .on
    }

	func updateNotificationSettings() {
		UNUserNotificationCenter.current().getNotificationSettings { (settings) in
			self.userNotificationSettings = settings
			if settings.authorizationStatus == .authorized {
				DispatchQueue.main.async {
					NSApplication.shared.registerForRemoteNotifications()
				}
			}
		}
	}

	func showNotificationsDeniedError() {
		let updateAlert = NSAlert()
		updateAlert.alertStyle = .informational
		updateAlert.messageText = NSLocalizedString("Enable Notifications", comment: "Notifications")
		updateAlert.informativeText = NSLocalizedString("To enable notifications, open Notifications in System Preferences, then find NetNewsWire in the list.", comment: "To enable notifications, open Notifications in System Preferences, then find NetNewsWire in the list.")
		updateAlert.addButton(withTitle: NSLocalizedString("Open System Preferences", comment: "Open System Preferences"))
		updateAlert.addButton(withTitle: NSLocalizedString("Close", comment: "Close"))
		let modalResponse = updateAlert.runModal()
		if modalResponse == .alertFirstButtonReturn {
			NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
		}
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
