//
//  FeedInspectorViewController.swift
//  Evergreen
//
//  Created by Brent Simmons on 1/20/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import Data

final class FeedInspectorViewController: NSViewController, Inspector {

	@IBOutlet var imageView: NSImageView!
	@IBOutlet var nameTextField: NSTextField!
	@IBOutlet var homePageURLTextField: NSTextField!
	@IBOutlet var urlTextField: NSTextField!

	let isFallbackInspector = false
	var objects: [Any]? {
		didSet {
			updateUI()
		}
	}

	func canInspect(_ objects: [Any]) -> Bool {

		return objects.count == 1 && objects.first is Feed
	}

	func willEndInspectingObjects() {
		
		makeUIEmpty()
	}
}

private extension FeedInspectorViewController {

	private var feed: Feed? {
		guard let objects = objects, objects.count == 1, let feed = objects.first as? Feed else {
			return nil
		}
		return feed
	}

	func updateUI() {

		view.needsLayout = true

		guard let feed = feed else {
			makeUIEmpty()
			return
		}

		updateImage(feed)
		updateName(feed)
		updateHomePageURL(feed)
		updateFeedURL(feed)
	}

	func updateImage(_ feed: Feed) {

		if let image = appDelegate.feedIconDownloader.icon(for: feed) {
			imageView.image = image
		}
		else if let image = appDelegate.faviconDownloader.favicon(for: feed) {
			imageView.image = image
		}
		else {
			imageView.image = nil
		}
	}

	func updateName(_ feed: Feed) {

		nameTextField.stringValue = feed.editedName ?? feed.name ?? ""
	}

	func updateHomePageURL(_ feed: Feed) {

		homePageURLTextField.stringValue = feed.homePageURL ?? ""
	}

	func updateFeedURL(_ feed: Feed) {

		urlTextField.stringValue = feed.url
	}

	func makeUIEmpty() {

		imageView.image = nil
		nameTextField.stringValue = ""
		homePageURLTextField.stringValue = ""
		urlTextField.stringValue = ""
	}
}
