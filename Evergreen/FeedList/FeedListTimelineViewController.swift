//
//  FeedListTimelineViewController.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/1/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Cocoa

final class FeedListTimelineViewController: NSViewController {

	var selectedFeed: FeedListFeed? = nil {
		didSet {
			if let selectedFeed = selectedFeed {
				selectedFeed.downloadIfNeeded()
			}
		}
	}

	override func viewDidLoad() {

		view.translatesAutoresizingMaskIntoConstraints = false

		NotificationCenter.default.addObserver(self, selector: #selector(sidebarSelectionDidChange(_:)), name: .FeedListSidebarSelectionDidChange, object: nil)

		NotificationCenter.default.addObserver(self, selector: #selector(feedDidBecomeAvailable(_:)), name: .FeedListFeedDidBecomeAvailable, object: nil)
	}

	@objc func feedDidBecomeAvailable(_ note: Notification) {

		guard let feed = note.object as? FeedListFeed else {
			return
		}

		if feed == selectedFeed {
			reloadTimeline()
		}
	}

	@objc func sidebarSelectionDidChange(_ note: Notification) {

		guard let feed = note.userInfo?[FeedListUserInfoKey.selectedObject] as? FeedListFeed else {
			selectedFeed = nil
			return
		}
		selectedFeed = feed
	}
}

private extension FeedListTimelineViewController {

	func reloadTimeline() {
		//
	}
}
