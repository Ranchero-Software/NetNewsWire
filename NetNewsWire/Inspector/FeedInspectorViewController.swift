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
import DB5

final class FeedInspectorViewController: NSViewController, Inspector {

	@IBOutlet var imageView: NSImageView?
	@IBOutlet var nameTextField: NSTextField?
	@IBOutlet var homePageURLTextField: NSTextField?
	@IBOutlet var urlTextField: NSTextField?

	private var feed: Feed? {
		didSet {
			if feed != oldValue {
				updateUI()
			}
		}
	}

	// MARK: Inspector

	let isFallbackInspector = false
	var objects: [Any]? {
		didSet {
			updateFeed()
		}
	}

	func canInspect(_ objects: [Any]) -> Bool {

		return objects.count == 1 && objects.first is Feed
	}

	// MARK: NSViewController

	override func viewDidLoad() {

		imageView!.wantsLayer = true
		let cornerRadius = appDelegate.currentTheme.float(forKey: "MainWindow.Timeline.cell.avatarCornerRadius")
		imageView!.layer?.cornerRadius = cornerRadius

		updateUI()

		NotificationCenter.default.addObserver(self, selector: #selector(imageDidBecomeAvailable(_:)), name: .ImageDidBecomeAvailable, object: nil)
	}

	// MARK: Notifications

	@objc func imageDidBecomeAvailable(_ note: Notification) {

		updateImage()
	}
}

extension FeedInspectorViewController: NSTextFieldDelegate {

	func controlTextDidChange(_ note: Notification) {

		guard let feed = feed, let nameTextField = nameTextField else {
			return
		}
		feed.editedName = nameTextField.stringValue
	}
}

private extension FeedInspectorViewController {

	func updateFeed() {

		guard let objects = objects, objects.count == 1, let singleFeed = objects.first as? Feed else {
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

		view.needsLayout = true
	}

	func updateImage() {

		guard let feed = feed else {
			imageView?.image = nil
			return
		}

		if let feedIcon = appDelegate.feedIconDownloader.icon(for: feed) {
			imageView?.image = feedIcon
			return
		}

		if let favicon = appDelegate.faviconDownloader.favicon(for: feed) {
			if favicon.size.height < 16.0 && favicon.size.width < 16.0 {
				favicon.size = NSSize(width: 16, height: 16)
			}
			imageView?.image = favicon
			return
		}

		imageView?.image = AppImages.genericFeedImage
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

		homePageURLTextField?.stringValue = feed?.homePageURL ?? ""
	}

	func updateFeedURL() {

		urlTextField?.stringValue = feed?.url ?? ""
	}
}
