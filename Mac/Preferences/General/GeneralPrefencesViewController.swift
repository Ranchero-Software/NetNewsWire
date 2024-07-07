//
//  GeneralPrefencesViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/3/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import Web
import UserNotifications
import UniformTypeIdentifiers

final class GeneralPreferencesViewController: NSViewController {

	private var userNotificationSettings: UNNotificationSettings?

	@IBOutlet weak var articleThemePopup: NSPopUpButton!
	@IBOutlet weak var defaultBrowserPopup: NSPopUpButton!

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

	@objc func articleThemeNamesDidChangeNotification(_ note: Notification) {
		updateArticleThemePopup()
	}

	// MARK: - Actions

	@IBAction func showThemesFolder(_ sender: Any) {
		NSWorkspace.shared.open(ArticleThemesManager.shared.folderURL)
	}
	
	@IBAction func articleThemePopUpDidChange(_ sender: Any) {
		guard let menuItem = articleThemePopup.selectedItem else {
			return
		}
		ArticleThemesManager.shared.currentThemeName = menuItem.title
		updateArticleThemePopup()
	}
	
	@IBAction func browserPopUpDidChangeValue(_ sender: Any?) {
		guard let menuItem = defaultBrowserPopup.selectedItem else {
			return
		}
		let bundleID = menuItem.representedObject as? String
		AppDefaults.shared.defaultBrowserID = bundleID
		updateBrowserPopup()
	}

}

// MARK: - Private

private extension GeneralPreferencesViewController {

	func commonInit() {
		NotificationCenter.default.addObserver(self, selector: #selector(applicationWillBecomeActive(_:)), name: NSApplication.willBecomeActiveNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(articleThemeNamesDidChangeNotification(_:)), name: .ArticleThemeNamesDidChangeNotification, object: nil)
	}

	func updateUI() {
		updateArticleThemePopup()
		updateBrowserPopup()
	}
	
	func updateArticleThemePopup() {
		let menu = articleThemePopup.menu!
		menu.removeAllItems()
		
		menu.addItem(NSMenuItem(title: ArticleTheme.defaultTheme.name, action: nil, keyEquivalent: ""))
		menu.addItem(NSMenuItem.separator())

		for themeName in ArticleThemesManager.shared.themeNames {
			menu.addItem(NSMenuItem(title: themeName, action: nil, keyEquivalent: ""))
		}
		
		articleThemePopup.selectItem(withTitle: ArticleThemesManager.shared.currentThemeName)
		if articleThemePopup.indexOfSelectedItem == -1 {
			articleThemePopup.selectItem(withTitle: ArticleTheme.defaultTheme.name)
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

		for browser in allBrowsers {
			guard let name = browser.name else { continue }

			let item = NSMenuItem(title: name, action: nil, keyEquivalent: "")
			item.representedObject = browser.bundleIdentifier

			let icon = browser.icon ?? NSWorkspace.shared.icon(for: UTType.applicationBundle)
			icon.size = NSSize(width: 16.0, height: 16.0)
			item.image = browser.icon
			menu.addItem(item)
		}

		defaultBrowserPopup.selectItem(at: defaultBrowserPopup.indexOfItem(withRepresentedObject: AppDefaults.shared.defaultBrowserID))
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

	@objc var openFeedsInDefaultNewsReader: Bool {
		get {
			return AppDefaults.shared.subscribeToFeedsInDefaultBrowser
		}
		set {
			AppDefaults.shared.subscribeToFeedsInDefaultBrowser = newValue
		}
	}
}
