//
//  SidebarProgressView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/17/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import RSCore
import Articles
import RSWeb
import Account

final class SidebarProgressView: NSView {
	@IBOutlet var progressIndicator: NSProgressIndicator!
	@IBOutlet var progressLabel: NSTextField!
	@IBOutlet var bottomConstraint: NSLayoutConstraint!
	@IBOutlet var heightConstraint: NSLayoutConstraint!

	/// When true, the view stays hidden and shows no progress.
	/// When collapsed, this view sits just below the sidebar, unclipped — where the main window status bar is.
	/// Its separator would double the status bar’s top line, so it’s hidden while suppressed.
	var isSuppressed = false {
		didSet {
			if isSuppressed != oldValue {
				isHidden = isSuppressed
				updateUI()
			}
		}
	}

	private var isAnimatingProgress = false

	nonisolated override var isFlipped: Bool {
		return true
	}

	override func awakeFromNib() {
		MainActor.assumeIsolated {
			progressIndicator.isHidden = true
			progressLabel.isHidden = true

			let progressLabelFontSize = progressLabel.font?.pointSize ?? 13.0
			progressLabel.font = NSFont.monospacedDigitSystemFont(ofSize: progressLabelFontSize, weight: NSFont.Weight.regular)
			progressLabel.stringValue = ""

			NotificationCenter.default.addObserver(self, selector: #selector(progressInfoDidChange(_:)), name: .progressInfoDidChange, object: CombinedRefreshProgress.shared)
		}
	}

	@objc func updateUI() {

		updateProgressIndicator()
		updateProgressLabel()
	}

	// MARK: Notifications

	@objc func progressInfoDidChange(_ notification: Notification) {
		CoalescingQueue.standard.add(self, #selector(updateUI))
	}
}

private extension SidebarProgressView {

	// MARK: Progress

	static let animationDuration = 0.2

	func stopProgressIfNeeded() {

		if !isAnimatingProgress {
			return
		}
		isAnimatingProgress = false
		progressIndicator.stopAnimation(self)
		progressIndicator.isHidden = true
		progressLabel.isHidden = true

		superview?.layoutSubtreeIfNeeded()

		NSAnimationContext.runAnimationGroup { context in
			context.duration = SidebarProgressView.animationDuration
			context.allowsImplicitAnimation = true
			bottomConstraint.constant = -(heightConstraint.constant)
			superview?.layoutSubtreeIfNeeded()
		}
	}

	func startProgressIfNeeded() {

		if isAnimatingProgress {
			return
		}
		isAnimatingProgress = true
		progressIndicator.isHidden = false
		progressLabel.isHidden = false
		progressIndicator.startAnimation(self)

		superview?.layoutSubtreeIfNeeded()

		NSAnimationContext.runAnimationGroup { context in
			context.duration = SidebarProgressView.animationDuration
			context.allowsImplicitAnimation = true
			bottomConstraint.constant = 0
			superview?.layoutSubtreeIfNeeded()
		}
	}

	func updateProgressIndicator() {

		let progressInfo = CombinedRefreshProgress.shared.progressInfo

		if progressInfo.isComplete || isSuppressed {
			stopProgressIfNeeded()
			return
		}

		startProgressIfNeeded()

		let maxValue = Double(progressInfo.numberOfTasks)
		if progressIndicator.maxValue != maxValue {
			progressIndicator.maxValue = maxValue
		}

		let doubleValue = Double(progressInfo.numberCompleted)
		if progressIndicator.doubleValue != doubleValue {
			progressIndicator.doubleValue = doubleValue
		}
	}

	func updateProgressLabel() {

		let progressInfo = CombinedRefreshProgress.shared.progressInfo

		if progressInfo.isComplete {
			progressLabel.stringValue = ""
			return
		}

		let formatString = NSLocalizedString("%@ of %@", comment: "Status bar progress")
		let s = String(format: formatString, NSNumber(value: progressInfo.numberCompleted), NSNumber(value: progressInfo.numberOfTasks))

		progressLabel.stringValue = s
	}
}
