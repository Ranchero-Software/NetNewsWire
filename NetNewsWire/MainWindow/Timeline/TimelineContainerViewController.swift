//
//  TimelineContainerViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/14/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Cocoa

final class TimelineContainerViewController: NSViewController {

	@IBOutlet var containerView: TimelineContainerView!
	
	private lazy var regularTimelineViewController = {
		return TimelineViewController(delegate: self)
	}()
	private lazy var searchTimelineViewController = {
		return TimelineViewController(delegate: self)
	}()

    override func viewDidLoad() {
        super.viewDidLoad()
        setRepresentedObjects(nil, mode: .regular)
		showTimeline(.regular)
    }

	// MARK: - API

	func setRepresentedObjects(_ objects: [AnyObject]?, mode: TimelineSourceMode) {
		timelineViewController(for: mode).representedObjects = objects
	}

	func showTimeline(_ mode: TimelineSourceMode) {
		containerView.contentView = timelineViewController(for: mode).view
	}
}

extension TimelineContainerViewController: TimelineDelegate {

	func selectionDidChange(in: TimelineViewController) {
		// TODO: notify MainWindowController
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
}
