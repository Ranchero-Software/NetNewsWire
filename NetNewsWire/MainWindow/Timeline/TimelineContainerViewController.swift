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

	private lazy var regularTimelineViewController = {
		return TimelineViewController(delegate: self)
	}()
	private lazy var searchTimelineViewController = {
		return TimelineViewController(delegate: self)
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
