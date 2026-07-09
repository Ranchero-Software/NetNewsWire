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
	@IBOutlet var articleTextSizeLabel: NSTextField!
	@IBOutlet var articleTextSizePopup: NSPopUpButton!
	@IBOutlet var articleThemePopup: NSPopUpButton!
	@IBOutlet var defaultBrowserPopup: NSPopUpButton!

	private enum ArticleThemePopupItem {
		case selectionMode(ArticleThemeSelectionMode)
		case theme(ArticleThemeSetting)
	}

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
		fixArticleTextSizeBaselineIfNeeded()
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
		let url = URL(fileURLWithPath: ArticleThemesManager.shared.folderPath)
		NSWorkspace.shared.open(url)
	}

	@IBAction func articleThemePopUpDidChange(_ sender: Any) {
		guard let menuItem = articleThemePopup.selectedItem else {
			return
		}
		applyArticleThemePopupItem(menuItem)
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

	/// On macOS 15 the "Article Text Size:" label is vertically misaligned
	/// with its popup. Replace the firstBaseline constraint with a
	/// centerY constraint, which works.
	func fixArticleTextSizeBaselineIfNeeded() {
		if #available(macOS 26, *) {
			return
		}

		guard let superview = articleTextSizeLabel.superview else {
			return
		}

		for constraint in superview.constraints {
			let matchesBaseline =
				constraint.firstAttribute == .firstBaseline &&
				constraint.secondAttribute == .firstBaseline
			let involvesPopup =
				constraint.firstItem === articleTextSizePopup ||
				constraint.secondItem === articleTextSizePopup
			let involvesLabel =
				constraint.firstItem === articleTextSizeLabel ||
				constraint.secondItem === articleTextSizeLabel

			if matchesBaseline && involvesPopup && involvesLabel {
				superview.removeConstraint(constraint)
				articleTextSizeLabel.centerYAnchor.constraint(equalTo: articleTextSizePopup.centerYAnchor).isActive = true
				break
			}
		}
	}

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

		let sameThemeItem = articleThemeMenuItem(title: ArticleThemeSelectionMode.single.title, representedObject: ArticleThemePopupItem.selectionMode(.single))
		sameThemeItem.state = ArticleThemesManager.shared.themeSelectionMode == .single ? .on : .off
		menu.addItem(sameThemeItem)

		let matchAppearanceItem = articleThemeMenuItem(title: ArticleThemeSelectionMode.appearance.title, representedObject: ArticleThemePopupItem.selectionMode(.appearance))
		matchAppearanceItem.state = ArticleThemesManager.shared.themeSelectionMode == .appearance ? .on : .off
		menu.addItem(matchAppearanceItem)
		menu.addItem(NSMenuItem.separator())

		switch ArticleThemesManager.shared.themeSelectionMode {
		case .single:
			addThemeMenuItems(to: menu, setting: .single)
			articleThemePopup.selectItem(withTitle: ArticleThemesManager.shared.currentThemeName)
			if articleThemePopup.indexOfSelectedItem == -1 {
				articleThemePopup.selectItem(withTitle: ArticleTheme.defaultTheme.name)
			}
		case .appearance:
			addThemeSubmenu(to: menu, setting: .lightAppearance)
			addThemeSubmenu(to: menu, setting: .darkAppearance)
			articleThemePopup.selectItem(withTitle: ArticleThemeSelectionMode.appearance.title)
		}
	}

	@objc func articleThemeMenuItemSelected(_ menuItem: NSMenuItem) {
		applyArticleThemePopupItem(menuItem)
		updateArticleThemePopup()
	}

	func applyArticleThemePopupItem(_ menuItem: NSMenuItem) {
		guard let item = menuItem.representedObject as? ArticleThemePopupItem else {
			return
		}

		switch item {
		case .selectionMode(let mode):
			ArticleThemesManager.shared.themeSelectionMode = mode
		case .theme(let setting):
			ArticleThemesManager.shared.setThemeName(menuItem.title, for: setting)
		}
	}

	func addThemeSubmenu(to menu: NSMenu, setting: ArticleThemeSetting) {
		let submenuItem = NSMenuItem(title: setting.title, action: nil, keyEquivalent: "")
		let submenu = NSMenu()
		addThemeMenuItems(to: submenu, setting: setting)
		submenuItem.submenu = submenu
		menu.addItem(submenuItem)
	}

	func addThemeMenuItems(to menu: NSMenu, setting: ArticleThemeSetting) {
		let defaultThemeItem = articleThemeMenuItem(title: ArticleTheme.defaultTheme.name, representedObject: ArticleThemePopupItem.theme(setting))
		defaultThemeItem.state = ArticleTheme.defaultTheme.name == ArticleThemesManager.shared.themeName(for: setting) ? .on : .off
		menu.addItem(defaultThemeItem)
		menu.addItem(NSMenuItem.separator())

		for themeName in ArticleThemesManager.shared.themeNames {
			let themeItem = articleThemeMenuItem(title: themeName, representedObject: ArticleThemePopupItem.theme(setting))
			themeItem.state = themeName == ArticleThemesManager.shared.themeName(for: setting) ? .on : .off
			menu.addItem(themeItem)
		}
	}

	private func articleThemeMenuItem(title: String, representedObject: ArticleThemePopupItem) -> NSMenuItem {
		let menuItem = NSMenuItem(title: title, action: #selector(articleThemeMenuItemSelected(_:)), keyEquivalent: "")
		menuItem.target = self
		menuItem.representedObject = representedObject
		return menuItem
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

		defaultBrowserPopup.selectItem(at: defaultBrowserPopup.indexOfItem(withRepresentedObject: AppDefaults.shared.defaultBrowserID))
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
