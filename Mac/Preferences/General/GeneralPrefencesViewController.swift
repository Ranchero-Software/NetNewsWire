//
//  GeneralPrefencesViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/3/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import Account
import RSCore
import RSWeb
import Images
import UserNotifications
import UniformTypeIdentifiers

final class GeneralPreferencesViewController: NSViewController {
	@IBOutlet var articleTextSizeLabel: NSTextField!
	@IBOutlet var articleTextSizePopup: NSPopUpButton!
	@IBOutlet var articleThemePopup: NSPopUpButton!
	@IBOutlet var defaultBrowserPopup: NSPopUpButton!
	@IBOutlet var cacheImagesSizeLabel: NSTextField!

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

	/// The checkbox is bound to the default; this action (also wired to it) updates the
	/// cache-size line and, when the setting is switched on, offers to cache existing
	/// articles' images right away.
	@IBAction func cacheImagesForOfflineChanged(_ sender: Any) {
		updateOfflineImagesUI()
		if AppDefaults.shared.cacheImagesForOffline {
			promptToCacheAllImages()
		}
	}

	@objc func cacheAllImagesProgressDidChange(_ note: Notification) {
		updateOfflineImagesUI()
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
		NotificationCenter.default.addObserver(self, selector: #selector(cacheAllImagesProgressDidChange(_:)), name: .ArticleImageCacheAllProgressDidChange, object: nil)
	}

	func updateUI() {
		updateArticleThemePopup()
		updateBrowserPopup()
		updateOfflineImagesUI()
	}

	/// Show live progress during a "cache all" run, otherwise the current on-disk cache size,
	/// in the line beneath the checkbox. The size is only recomputed when a run isn't in
	/// progress, to avoid enumerating the cache folder on every progress tick.
	func updateOfflineImagesUI() {
		let prefetcher = ArticleImagePrefetcher.shared
		guard prefetcher.isCachingAll else {
			refreshCacheImagesSize()
			return
		}
		if prefetcher.cacheAllTotal > 0 {
			let format = NSLocalizedString("Caching Images… %d of %d", comment: "Cache-all progress")
			cacheImagesSizeLabel.stringValue = String(format: format, prefetcher.cacheAllCompleted, prefetcher.cacheAllTotal)
		} else {
			cacheImagesSizeLabel.stringValue = NSLocalizedString("Caching Images…", comment: "Cache-all starting")
		}
	}

	/// When offline caching is switched on, offer to backfill images for existing unread
	/// articles now — prefetch otherwise only catches images from future refreshes, and the
	/// moment someone enables this is usually right before they go offline.
	func promptToCacheAllImages() {
		guard !ArticleImagePrefetcher.shared.isCachingAll else {
			return
		}
		let unreadCount = AccountManager.shared.unreadCount
		guard unreadCount > 0 else {
			return
		}
		let alert = NSAlert()
		alert.alertStyle = .informational
		alert.messageText = NSLocalizedString("Cache Images Now?", comment: "Cache images now alert title")
		let format = NSLocalizedString("Download images for your %d unread articles now, so they can be read offline?", comment: "Cache images now alert message")
		alert.informativeText = String(format: format, unreadCount)
		alert.addButton(withTitle: NSLocalizedString("Cache Images", comment: "Cache Images now button"))
		alert.addButton(withTitle: NSLocalizedString("Not Now", comment: "Not Now"))
		if alert.runModal() == .alertFirstButtonReturn {
			ArticleImagePrefetcher.shared.cacheAllArticleImagesNow()
			updateOfflineImagesUI()
		}
	}

	func refreshCacheImagesSize() {
		Task { @MainActor in
			let stats = await ArticleImageDownloader.shared.cacheStats()
			if stats.byteCount > 0 {
				let size = stats.byteCount.formatted(.byteCount(style: .file))
				let format = NSLocalizedString("%d images · %@ used", comment: "Cached image count and size")
				cacheImagesSizeLabel.stringValue = String(format: format, stats.fileCount, size)
			} else {
				cacheImagesSizeLabel.stringValue = ""
			}
		}
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
