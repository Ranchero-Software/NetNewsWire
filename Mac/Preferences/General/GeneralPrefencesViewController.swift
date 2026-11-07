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
import UniformTypeIdentifiers

final class GeneralPreferencesViewController: NSViewController {
	@IBOutlet var defaultBrowserPopup: NSPopUpButton!
	@IBOutlet var showUnreadCountsButton: NSButton?
	@IBOutlet var showUnreadCountDotButton: NSButton?
	@IBOutlet var hideUnreadCountsButton: NSButton?

	convenience init() {
		self.init(nibName: "GeneralPreferencesView", bundle: nil)
	}

	public override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
		super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
		commonInit()
	}

	public required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		view.sizeToFittingSize()
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

	@objc func handleUnreadCountDisplaySettingDidChange(_ notification: Notification) {
		updateUnreadCountDisplayButtons()
	}

	// MARK: - Actions

	@IBAction func unreadCountDisplaySettingDidChange(_ sender: NSButton) {
		guard let unreadCountDisplay = UnreadCountDisplay(rawValue: sender.tag) else {
			return
		}
		AppDefaults.unreadCountDisplay = unreadCountDisplay
	}

	@IBAction func browserPopUpDidChangeValue(_ sender: Any?) {
		guard let menuItem = defaultBrowserPopup.selectedItem else {
			return
		}

		let bundleID = menuItem.representedObject as? String
		AppDefaults.defaultBrowserID = bundleID
		updateBrowserPopup()
	}

}

// MARK: - Private

private extension GeneralPreferencesViewController {

	func commonInit() {
		NotificationCenter.default.addObserver(self, selector: #selector(applicationWillBecomeActive(_:)), name: NSApplication.willBecomeActiveNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleUnreadCountDisplaySettingDidChange(_:)), name: .unreadCountDisplaySettingDidChange, object: nil)
	}

	func updateUI() {
		updateBrowserPopup()
		updateUnreadCountDisplayButtons()
	}

	func updateUnreadCountDisplayButtons() {
		let selectedTag = AppDefaults.unreadCountDisplay.rawValue
		for case let button? in [showUnreadCountsButton, showUnreadCountDotButton, hideUnreadCountsButton] {
			button.state = button.tag == selectedTag ? .on : .off
		}
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

		let baseFont = NSFont.menuFont(ofSize: 0)
		let smallFont = NSFont.menuFont(ofSize: baseFont.pointSize - 2)

		let duplicates = MacWebBrowser.duplicateBrowserNames(in: allBrowsers)

		for browser in allBrowsers {
			guard let name = browser.name else { continue }

			let item = NSMenuItem(title: name, action: nil, keyEquivalent: "")
			item.representedObject = browser.bundlePath

			// override title with attributedTitle if browser name has duplicates
			if duplicates.contains(name) {
				let title = NSMutableAttributedString(
					string: name,
					attributes: [
						.font: NSFont.menuFont(ofSize: 0)
					]
				)

				title.append(NSAttributedString(
					string: " - \(MacWebBrowser.displayPath(of: browser.url))",
					attributes: [
						.font: smallFont,
						.foregroundColor: NSColor.secondaryLabelColor
					]
				))

				item.attributedTitle = title
			}

			let icon = browser.icon ?? NSWorkspace.shared.icon(for: UTType.applicationBundle)
			icon.size = NSSize(width: 16.0, height: 16.0)
			item.image = browser.icon
			menu.addItem(item)
		}

		defaultBrowserPopup.selectItem(at: defaultBrowserPopup.indexOfItem(withRepresentedObject: AppDefaults.defaultBrowserID))
	}

	func updateNotificationSettings() {
		UNUserNotificationCenter.current().getNotificationSettings { (settings) in
			if settings.authorizationStatus == .authorized {
				DispatchQueue.main.async {
					NSApplication.shared.registerForRemoteNotifications()
				}
			}
		}
	}

	@objc var openFeedsInDefaultNewsReader: Bool {
		get {
			return AppDefaults.subscribeToFeedsInDefaultBrowser
		}
		set {
			AppDefaults.subscribeToFeedsInDefaultBrowser = newValue
		}
	}
}
