//
//  MainWindowContentViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/11/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import AppKit

/// The main window’s content where the status bar is available: the split view controller above the status bar.
/// The split view controller is swapped when the timeline layout changes. The status bar stays.
final class MainWindowContentViewController: NSViewController {

	let statusBarView = MainWindowStatusBarView()

	var splitViewController: NSSplitViewController? {
		didSet {
			if splitViewController !== oldValue {
				replaceSplitViewController(oldValue)
			}
		}
	}

	var isStatusBarHidden = false {
		didSet {
			if isStatusBarHidden != oldValue {
				updateStatusBarVisibility()
			}
		}
	}

	private var splitViewBottomToStatusBarConstraint: NSLayoutConstraint?
	private var splitViewBottomToEdgeConstraint: NSLayoutConstraint?

	override func loadView() {
		view = NSView()

		statusBarView.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(statusBarView)
		NSLayoutConstraint.activate([
			statusBarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			statusBarView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			statusBarView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
		])
	}
}

// MARK: - Private

private extension MainWindowContentViewController {

	func replaceSplitViewController(_ oldSplitViewController: NSSplitViewController?) {
		if let oldSplitViewController {
			oldSplitViewController.view.removeFromSuperview()
			oldSplitViewController.removeFromParent()
		}
		splitViewBottomToStatusBarConstraint = nil
		splitViewBottomToEdgeConstraint = nil

		guard let splitViewController else {
			return
		}

		addChild(splitViewController)
		let splitView = splitViewController.view
		splitView.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(splitView, positioned: .below, relativeTo: statusBarView)

		splitViewBottomToStatusBarConstraint = splitView.bottomAnchor.constraint(equalTo: statusBarView.topAnchor)
		splitViewBottomToEdgeConstraint = splitView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
		NSLayoutConstraint.activate([
			splitView.topAnchor.constraint(equalTo: view.topAnchor),
			splitView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			splitView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
		])
		updateStatusBarVisibility()
	}

	func updateStatusBarVisibility() {
		statusBarView.isHidden = isStatusBarHidden
		// Deactivate before activating so the two bottom constraints never conflict.
		splitViewBottomToStatusBarConstraint?.isActive = false
		splitViewBottomToEdgeConstraint?.isActive = false
		let activeConstraint = isStatusBarHidden ? splitViewBottomToEdgeConstraint : splitViewBottomToStatusBarConstraint
		activeConstraint?.isActive = true
	}
}
