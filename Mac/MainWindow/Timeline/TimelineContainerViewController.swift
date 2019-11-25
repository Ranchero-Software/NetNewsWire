//
//  TimelineContainerViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/14/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import Articles

protocol TimelineContainerViewControllerDelegate: class {
	func timelineSelectionDidChange(_: TimelineContainerViewController, articles: [Article]?, mode: TimelineSourceMode)
}

final class TimelineContainerViewController: NSViewController {

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
    }

	// MARK: - API

	func setRepresentedObjects(_ objects: [AnyObject]?, mode: TimelineSourceMode) {
		timelineViewController(for: mode).representedObjects = objects
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
	
	func toggleReadFilter() {
		regularTimelineViewController.toggleReadFilter()
	}
	
}

extension TimelineContainerViewController: TimelineDelegate {

	func timelineSelectionDidChange(_ timelineViewController: TimelineViewController, selectedArticles: [Article]?) {
		delegate?.timelineSelectionDidChange(self, articles: selectedArticles, mode: mode(for: timelineViewController))
	}
}

private extension TimelineContainerViewController {

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
}
