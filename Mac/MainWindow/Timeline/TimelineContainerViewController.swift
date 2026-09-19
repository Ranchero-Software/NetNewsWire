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

@MainActor protocol TimelineContainerViewControllerDelegate: AnyObject {
	func timelineSelectionDidChange(_: TimelineContainerViewController, articles: [Article]?, mode: TimelineSourceMode)
	func timelineRequestedFeedSelection(_: TimelineContainerViewController, feed: Feed)
	func timelineInvalidatedRestorationState(_: TimelineContainerViewController)
}

final class TimelineContainerViewController: NSViewController {

	@IBOutlet var viewOptionsPopUpButton: NSPopUpButton!
	@IBOutlet var newestToOldestMenuItem: NSMenuItem!
	@IBOutlet var oldestToNewestMenuItem: NSMenuItem!
	@IBOutlet var groupByFeedMenuItem: NSMenuItem!

	@IBOutlet var readFilteredButton: NSButton!
	@IBOutlet var headerSeparator: NSBox!
	@IBOutlet var containerViewTopToHeaderConstraint: NSLayoutConstraint!
	@IBOutlet var containerView: TimelineContainerView!

	private var layout = AppDefaults.shared.timelineLayout {
		didSet {
			if layout != oldValue {
				layoutDidChange()
			}
		}
	}
	// Column layout hides the sort/filter header, and this pins the timeline to the top instead.
	private lazy var containerViewTopToViewConstraint = containerView.topAnchor.constraint(equalTo: view.topAnchor)

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

	var windowState: TimelineWindowState? {
		currentTimelineViewController?.windowState
	}

	/// This window’s sort. Both timelines (regular and search) follow it.
	private(set) var sortParameters = ArticleSortParameters(key: .date, direction: AppDefaults.shared.timelineSortDirection, groupByFeed: AppDefaults.shared.timelineGroupByFeed) {
		didSet {
			if sortParameters == oldValue {
				return
			}
			regularTimelineViewController.sortParameters = sortParameters
			searchTimelineViewController.sortParameters = sortParameters
			updateViewOptionsPopUpButton()
			delegate?.timelineInvalidatedRestorationState(self)
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
		let viewController = TimelineViewController(delegate: self)
		viewController.sortParameters = sortParameters
		viewController.layout = layout
		return viewController
	}()
	private lazy var searchTimelineViewController: TimelineViewController = {
		let viewController = TimelineViewController(delegate: self)
		viewController.showsSearchResults = true
		viewController.sortParameters = sortParameters
		viewController.layout = layout
		return viewController
	}()

	convenience init() {
		self.init(nibName: "TimelineContainerView", bundle: nil)
	}

    override func viewDidLoad() {
        super.viewDidLoad()
        setRepresentedObjects(nil, mode: .regular)
		showTimeline(for: .regular)

		makeMenuItemTitleLarger(newestToOldestMenuItem)
		makeMenuItemTitleLarger(oldestToNewestMenuItem)
		makeMenuItemTitleLarger(groupByFeedMenuItem)
		updateViewOptionsPopUpButton()
		updateHeaderVisibility()

		NotificationCenter.default.addObserver(self, selector: #selector(handleUserDefaultsDidChange(_:)), name: UserDefaults.didChangeNotification, object: nil)
    }

	// MARK: - Notifications

	@objc nonisolated func handleUserDefaultsDidChange(_ note: Notification) {
		Task { @MainActor in
			self.userDefaultsDidChange()
		}
	}

	private func userDefaultsDidChange() {
		layout = AppDefaults.shared.timelineLayout
	}

	// MARK: - API

	func sortByDate(_ direction: ComparisonResult) {
		sortParameters = sortParameters.withKey(.date, direction: direction)
	}

	func toggleGroupByFeed() {
		sortParameters = sortParameters.withGroupByFeed(!sortParameters.groupByFeed)
	}

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
			if currentObjects.firstIndex(where: { $0 === object }) == nil {
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

	func restoreState(from state: TimelineWindowState?) {
		guard let state else { return }

		// Sort first so the restored selection lands in the right row.
		if let savedSortParameters = state.sortParameters {
			sortParameters = sortParametersAllowedByLayout(savedSortParameters)
		}
		regularTimelineViewController.restoreState(from: state)
		updateReadFilterButton()
	}

	/// Restore state using legacy state restoration data.
	///
	/// TODO: Delete for NetNewsWire 7.
	func restoreLegacyState(from state: [AnyHashable: Any]) {
		regularTimelineViewController.restoreLegacyState(from: state)
		updateReadFilterButton()
	}
}

extension TimelineContainerViewController: TimelineDelegate {

	func timelineSelectionDidChange(_ timelineViewController: TimelineViewController, selectedArticles: [Article]?) {
		delegate?.timelineSelectionDidChange(self, articles: selectedArticles, mode: mode(for: timelineViewController))
	}

	func timelineRequestedFeedSelection(_: TimelineViewController, feed: Feed) {
		delegate?.timelineRequestedFeedSelection(self, feed: feed)
	}

	func timelineInvalidatedRestorationState(_: TimelineViewController) {
		delegate?.timelineInvalidatedRestorationState(self)
	}

	func timelineRequestedSortChange(_: TimelineViewController, parameters: ArticleSortParameters) {
		sortParameters = parameters
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
		} else if timelineViewController === searchTimelineViewController {
			return .search
		}
		assertionFailure("Expected timelineViewController to match either regular or search timelineViewController, but it doesn’t.")
		return .regular // Should never get here.
	}

	func updateViewOptionsPopUpButton() {
		guard isViewLoaded else {
			return
		}
		if sortParameters.direction == .orderedAscending {
			newestToOldestMenuItem.state = .off
			oldestToNewestMenuItem.state = .on
			viewOptionsPopUpButton.setTitle(oldestToNewestMenuItem.title)
		} else {
			newestToOldestMenuItem.state = .on
			oldestToNewestMenuItem.state = .off
			viewOptionsPopUpButton.setTitle(newestToOldestMenuItem.title)
		}

		groupByFeedMenuItem.state = sortParameters.groupByFeed ? .on : .off
	}

	func layoutDidChange() {
		sortParameters = sortParametersAllowedByLayout(sortParameters)
		regularTimelineViewController.layout = layout
		searchTimelineViewController.layout = layout
		updateHeaderVisibility()
	}

	/// Standard layout sorts by date only.
	func sortParametersAllowedByLayout(_ parameters: ArticleSortParameters) -> ArticleSortParameters {
		if layout == .standard && parameters.key != .date {
			return parameters.withKey(.date, direction: .orderedDescending)
		}
		return parameters
	}

	func updateHeaderVisibility() {
		let isHeaderHidden = layout == .column
		viewOptionsPopUpButton.isHidden = isHeaderHidden
		headerSeparator.isHidden = isHeaderHidden
		containerViewTopToHeaderConstraint.isActive = !isHeaderHidden
		containerViewTopToViewConstraint.isActive = isHeaderHidden
		updateReadFilterButton()
	}

	func updateReadFilterButton() {
		guard layout == .standard else {
			readFilteredButton.isHidden = true
			return
		}

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
			readFilteredButton.image = Assets.Images.filterActive
		} else {
			readFilteredButton.image = Assets.Images.filterInactive
		}
	}

}
