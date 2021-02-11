//
//  TimelineContainerViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/14/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import Account
import Articles

protocol TimelineContainerViewControllerDelegate: AnyObject {
	func timelineSelectionDidChange(_: TimelineContainerViewController, articles: [Article]?, mode: TimelineSourceMode)
	func timelineRequestedWebFeedSelection(_: TimelineContainerViewController, webFeed: WebFeed)
	func timelineInvalidatedRestorationState(_: TimelineContainerViewController)

}

final class TimelineContainerViewController: NSViewController {

	@IBOutlet weak var viewOptionsPopUpButton: NSPopUpButton!
	@IBOutlet weak var newestToOldestMenuItem: NSMenuItem!
	@IBOutlet weak var oldestToNewestMenuItem: NSMenuItem!
	@IBOutlet weak var groupByFeedMenuItem: NSMenuItem!
	
	@IBOutlet weak var readFilteredButton: NSButton!
	@IBOutlet var containerView: TimelineContainerView!

	var currentTimelineViewController: TimelineViewController? {
		didSet {
			let view = currentTimelineViewController?.view
			if containerView.contentView === view {
				return
			}
			containerView.contentView = view
			view?.window?.recalculateKeyViewLoop()
		}
	}

	weak var delegate: TimelineContainerViewControllerDelegate?

	var isReadFiltered: Bool? {
		guard let currentTimelineViewController = currentTimelineViewController, mode(for: currentTimelineViewController) == .regular else { return nil }
		return regularTimelineViewController.isReadFiltered
	}

	var isCleanUpAvailable: Bool {
		guard let currentTimelineViewController = currentTimelineViewController, mode(for: currentTimelineViewController) == .regular else { return false }
		return regularTimelineViewController.isCleanUpAvailable
	}
	
	lazy var regularTimelineViewController = {
		return TimelineViewController(delegate: self)
	}()
	private lazy var searchTimelineViewController: TimelineViewController = {
		let viewController = TimelineViewController(delegate: self)
		viewController.showsSearchResults = true
		return viewController
	}()

    override func viewDidLoad() {
        super.viewDidLoad()
        setRepresentedObjects(nil, mode: .regular)
		showTimeline(for: .regular)
		
		makeMenuItemTitleLarger(newestToOldestMenuItem)
		makeMenuItemTitleLarger(oldestToNewestMenuItem)
		makeMenuItemTitleLarger(groupByFeedMenuItem)
		updateViewOptionsPopUpButton()
		
		NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange(_:)), name: UserDefaults.didChangeNotification, object: nil)
    }
	
	// MARK: - Notifications
	
	@objc func userDefaultsDidChange(_ note: Notification) {
		updateViewOptionsPopUpButton()
	}
	
	// MARK: - API

	func setRepresentedObjects(_ objects: [AnyObject]?, mode: TimelineSourceMode) {
		timelineViewController(for: mode).representedObjects = objects
		updateReadFilterButton()
	}

	func showTimeline(for mode: TimelineSourceMode) {
		currentTimelineViewController = timelineViewController(for: mode)
	}

	func regularTimelineViewControllerHasRepresentedObjects(_ representedObjects: [AnyObject]?) -> Bool {
		// Use this to find out if the regular timeline view already has the specified representedObjects.
		// This is used in determining whether a search should end.
		// The sidebar may think that the selection has changed, and therefore search should end —
		// but it could be that the regular timeline already has these representedObjects,
		// and therefore the selection hasn’t actually changed,
		// and therefore search shouldn’t end.
		// https://github.com/brentsimmons/NetNewsWire/issues/791
		if representedObjects == nil && regularTimelineViewController.representedObjects == nil {
			return true
		}
		guard let currentObjects = regularTimelineViewController.representedObjects, let representedObjects = representedObjects else {
			return false
		}
		if currentObjects.count != representedObjects.count {
			return false
		}
		for object in representedObjects {
			guard let _ = currentObjects.firstIndex(where: { $0 === object } ) else {
				return false
			}
		}
		return true
	}
	
	func cleanUp() {
		regularTimelineViewController.cleanUp()
	}
	
	func toggleReadFilter() {
		regularTimelineViewController.toggleReadFilter()
		updateReadFilterButton()
	}
	
	// MARK: State Restoration
	
	func saveState(to state: inout [AnyHashable : Any]) {
		regularTimelineViewController.saveState(to: &state)
	}
	
	func restoreState(from state: [AnyHashable : Any]) {
		regularTimelineViewController.restoreState(from: state)
		updateReadFilterButton()
	}
}

extension TimelineContainerViewController: TimelineDelegate {

	func timelineSelectionDidChange(_ timelineViewController: TimelineViewController, selectedArticles: [Article]?) {
		delegate?.timelineSelectionDidChange(self, articles: selectedArticles, mode: mode(for: timelineViewController))
	}

	func timelineRequestedWebFeedSelection(_: TimelineViewController, webFeed: WebFeed) {
		delegate?.timelineRequestedWebFeedSelection(self, webFeed: webFeed)
	}
	
	func timelineInvalidatedRestorationState(_: TimelineViewController) {
		delegate?.timelineInvalidatedRestorationState(self)
	}
	
}

private extension TimelineContainerViewController {

	func makeMenuItemTitleLarger(_ menuItem: NSMenuItem) {
		menuItem.attributedTitle = NSAttributedString(string: menuItem.title,
													  attributes: [NSAttributedString.Key.font: NSFont.controlContentFont(ofSize: NSFont.systemFontSize)])
	}
	
	func timelineViewController(for mode: TimelineSourceMode) -> TimelineViewController {
		switch mode {
		case .regular:
			return regularTimelineViewController
		case .search:
			return searchTimelineViewController
		}
	}

	func mode(for timelineViewController: TimelineViewController) -> TimelineSourceMode {
		if timelineViewController === regularTimelineViewController {
			return .regular
		}
		else if timelineViewController === searchTimelineViewController {
			return .search
		}
		assertionFailure("Expected timelineViewController to match either regular or search timelineViewController, but it doesn’t.")
		return .regular // Should never get here.
	}
	
	func updateViewOptionsPopUpButton() {
		if AppDefaults.shared.timelineSortDirection == .orderedAscending {
			newestToOldestMenuItem.state = .off
			oldestToNewestMenuItem.state = .on
			viewOptionsPopUpButton.setTitle(oldestToNewestMenuItem.title)
		} else {
			newestToOldestMenuItem.state = .on
			oldestToNewestMenuItem.state = .off
			viewOptionsPopUpButton.setTitle(newestToOldestMenuItem.title)
		}
		
		if AppDefaults.shared.timelineGroupByFeed == true {
			groupByFeedMenuItem.state = .on
		} else {
			groupByFeedMenuItem.state = .off
		}
	}
	
	func updateReadFilterButton() {
		guard currentTimelineViewController == regularTimelineViewController else {
			readFilteredButton.isHidden = true
			return
		}
		
		guard let isReadFiltered = regularTimelineViewController.isReadFiltered else {
			readFilteredButton.isHidden = true
			return
		}
		
		readFilteredButton.isHidden = false
		
		if isReadFiltered {
			readFilteredButton.image = AppAssets.filterActive
		} else {
			readFilteredButton.image = AppAssets.filterInactive
		}
	}
	
}
