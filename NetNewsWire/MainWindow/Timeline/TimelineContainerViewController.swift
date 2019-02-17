//
//  TimelineContainerViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/14/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Cocoa

enum TimelineState {
	case empty
	case representedObjects([AnyObject])
}

final class TimelineContainerViewController: NSViewController {

	@IBOutlet var containerView: TimelineContainerView!
	
	private var states: [TimelineSourceMode: TimelineState] = [.regular: .empty, .search: .empty]

	private lazy var regularTimelineViewController = {
		return TimelineViewController(delegate: self)
	}()
	private lazy var searchTimelineViewController = {
		return TimelineViewController(delegate: self)
	}()

    override func viewDidLoad() {
        super.viewDidLoad()
        setState(.empty, mode: .regular)
		showTimeline(for: .regular)
    }

	// MARK: - API

	func setState(_ state: TimelineState, mode: TimelineSourceMode) {
		timelineViewController(for: mode).state = state
	}

	func showTimeline(for mode: TimelineSourceMode) {
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
