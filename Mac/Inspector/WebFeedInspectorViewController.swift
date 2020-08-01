//
//  FeedInspectorViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 1/20/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import Articles
import Account
import UserNotifications

final class WebFeedInspectorViewController: NSViewController, Inspector {

	@IBOutlet weak var iconView: IconView!
	@IBOutlet weak var nameTextField: NSTextField?
	@IBOutlet weak var homePageURLTextField: NSTextField?
	@IBOutlet weak var urlTextField: NSTextField?
	@IBOutlet weak var isNotifyAboutNewArticlesCheckBox: NSButton!
	@IBOutlet weak var isReaderViewAlwaysOnCheckBox: NSButton?
	
	private var feed: WebFeed? {
		didSet {
			if feed != oldValue {
				updateUI()
			}
		}
	}

	private var userNotificationSettings: UNNotificationSettings?

	// MARK: Inspector

	let isFallbackInspector = false
	var objects: [Any]? {
		didSet {
			updateFeed()
		}
	}

	func canInspect(_ objects: [Any]) -> Bool {
		return objects.count == 1 && objects.first is WebFeed
	}

	// MARK: NSViewController

	override func viewDidLoad() {
		updateUI()
		NotificationCenter.default.addObserver(self, selector: #selector(imageDidBecomeAvailable(_:)), name: .ImageDidBecomeAvailable, object: nil)
	}
	
	override func viewDidAppear() {
		updateNotificationSettings()
	}
	
	// MARK: Actions
	@IBAction func isNotifyAboutNewArticlesChanged(_ sender: Any) {
		guard let settings = userNotificationSettings else  {
			// Something went wront fetching the user notification settings,
			// so toggle the checkbox back to its original state and return.
			isNotifyAboutNewArticlesCheckBox.setNextState()
			return
		}
		if settings.authorizationStatus == .denied {
			// Notifications are not authorized, so toggle the checkbox back
			// to its original state...
			isNotifyAboutNewArticlesCheckBox.setNextState()
			// ...and then alert the user to the issue
			// TODO: present alert to user
		} else if settings.authorizationStatus == .authorized {
			// Notifications are authorized, so set the feed's isNotifyAboutNewArticles
			// property to match the state of isNotifyAboutNewArticlesCheckbox.
			feed?.isNotifyAboutNewArticles = (isNotifyAboutNewArticlesCheckBox?.state ?? .off) == .on ? true : false
		} else {
			// We're not sure what the status may be but we've /probably/ not requested
			// permission to send notifications, so do that:
			UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .sound, .alert]) { (granted, error) in
				self.updateNotificationSettings()
				if granted {
					// We've been given permission, so set the feed's isNotifyAboutNewArticles
					// property to match the state of isNotifyAboutNewArticlesCheckbox and then
					// register for remote notifications.
					self.feed?.isNotifyAboutNewArticles = (self.isNotifyAboutNewArticlesCheckBox?.state ?? .off) == .on ? true : false
					NSApplication.shared.registerForRemoteNotifications()
				} else {
					// We weren't given permission, so toggle the checkbox back to its
					// original state.
					self.isNotifyAboutNewArticlesCheckBox.setNextState()
				}
			}
		}
	}
	
	@IBAction func isReaderViewAlwaysOnChanged(_ sender: Any) {
		feed?.isArticleExtractorAlwaysOn = (isReaderViewAlwaysOnCheckBox?.state ?? .off) == .on ? true : false
	}
	
	// MARK: Notifications

	@objc func imageDidBecomeAvailable(_ note: Notification) {
		updateImage()
	}
	
}

extension WebFeedInspectorViewController: NSTextFieldDelegate {

	func controlTextDidChange(_ note: Notification) {
		guard let feed = feed, let nameTextField = nameTextField else {
			return
		}
		feed.editedName = nameTextField.stringValue
	}
	
}

private extension WebFeedInspectorViewController {

	func updateFeed() {
		guard let objects = objects, objects.count == 1, let singleFeed = objects.first as? WebFeed else {
			feed = nil
			return
		}
		feed = singleFeed
	}

	func updateUI() {
		updateImage()
		updateName()
		updateHomePageURL()
		updateFeedURL()
		updateNotifyAboutNewArticles()
		updateIsReaderViewAlwaysOn()
		
		view.needsLayout = true
	}

	func updateImage() {
		guard let feed = feed, let iconView = iconView else {
			return
		}

		if let feedIcon = appDelegate.webFeedIconDownloader.icon(for: feed) {
			iconView.iconImage = feedIcon
			return
		}

		if let favicon = appDelegate.faviconDownloader.favicon(for: feed) {
			iconView.iconImage = favicon
			return
		}

		iconView.iconImage = feed.smallIcon
	}

	func updateName() {
		guard let nameTextField = nameTextField else {
			return
		}

		let name = feed?.editedName ?? feed?.name ?? ""
		if nameTextField.stringValue != name {
			nameTextField.stringValue = name
		}
	}

	func updateHomePageURL() {
		homePageURLTextField?.stringValue = feed?.homePageURL?.decodedURLString ?? ""
	}

	func updateFeedURL() {
		urlTextField?.stringValue = feed?.url.decodedURLString ?? ""
	}

	func updateNotificationSettings() {
		UNUserNotificationCenter.current().getNotificationSettings { (settings) in
			DispatchQueue.main.async {
				self.userNotificationSettings = settings
				if settings.authorizationStatus == .authorized {
					NSApplication.shared.registerForRemoteNotifications()
				}
			}
		}
	}

	func updateNotifyAboutNewArticles() {
		isNotifyAboutNewArticlesCheckBox?.state = (feed?.isNotifyAboutNewArticles ?? false) ? .on : .off
	}

	func updateIsReaderViewAlwaysOn() {
		isReaderViewAlwaysOnCheckBox?.state = (feed?.isArticleExtractorAlwaysOn ?? false) ? .on : .off
	}
}
