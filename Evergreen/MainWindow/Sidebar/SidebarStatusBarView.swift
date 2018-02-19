//
//  SidebarStatusBarView.swift
//  Evergreen
//
//  Created by Brent Simmons on 9/17/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import RSCore
import Data
import RSWeb
import Account

final class SidebarStatusBarView: NSView {

	@IBOutlet var progressIndicator: NSProgressIndicator!
	@IBOutlet var progressLabel: NSTextField!

	private var didConfigureLayer = false

	private var isAnimatingProgress = false {
		didSet {
			progressIndicator.isHidden = !isAnimatingProgress
			progressLabel.isHidden = !isAnimatingProgress
		}
	}

	private var progress: CombinedRefreshProgress? = nil {
		didSet {
			CoalescingQueue.standard.add(self, #selector(updateUI))
		}
	}
	override var isFlipped: Bool {
		return true
	}

	override var wantsUpdateLayer: Bool {
		return true
	}

	override func awakeFromNib() {

		progressIndicator.isHidden = true
		progressLabel.isHidden = true

		let progressLabelFontSize = progressLabel.font?.pointSize ?? 13.0
		progressLabel.font = NSFont.monospacedDigitSystemFont(ofSize: progressLabelFontSize, weight: NSFont.Weight.regular)
		progressLabel.stringValue = ""		
		
		NotificationCenter.default.addObserver(self, selector: #selector(progressDidChange(_:)), name: .AccountRefreshProgressDidChange, object: nil)
	}

	override func updateLayer() {

		guard let layer = layer, !didConfigureLayer else {
			return
		}

		let color = NSColor(calibratedWhite: 0.96, alpha: 1.0)
		layer.backgroundColor = color.cgColor
		didConfigureLayer = true
	}

	@objc func updateUI() {

		guard let progress = progress else {
			stopProgressIfNeeded()
			return
		}

		updateProgressIndicator(progress)
		updateProgressLabel(progress)
	}

	// MARK: Notifications

	@objc dynamic func progressDidChange(_ notification: Notification) {

		progress = AccountManager.shared.combinedRefreshProgress
	}
}

private extension SidebarStatusBarView {

	// MARK: Progress
	
	func stopProgressIfNeeded() {

		if !isAnimatingProgress {
			return
		}

		progressIndicator.stopAnimation(self)
		isAnimatingProgress = false
		progressIndicator.needsDisplay = true
	}

	func startProgressIfNeeded() {

		if isAnimatingProgress {
			return
		}
		isAnimatingProgress = true
		progressIndicator.startAnimation(self)
	}

	func updateProgressIndicator(_ progress: CombinedRefreshProgress) {

		if progress.isComplete {
			stopProgressIfNeeded()
			return
		}

		startProgressIfNeeded()

		let maxValue = Double(progress.numberOfTasks)
		if progressIndicator.maxValue != maxValue {
			progressIndicator.maxValue = maxValue
		}

		let doubleValue = Double(progress.numberCompleted)
		if progressIndicator.doubleValue != doubleValue {
			progressIndicator.doubleValue = doubleValue
		}
	}

	func updateProgressLabel(_ progress: CombinedRefreshProgress) {

		if progress.isComplete {
			progressLabel.stringValue = ""
			return
		}

		let numberOfTasks = progress.numberOfTasks
		let numberCompleted = progress.numberCompleted

		let formatString = NSLocalizedString("%@ of %@", comment: "Status bar progress")
		let s = NSString(format: formatString as NSString, NSNumber(value: numberCompleted), NSNumber(value: numberOfTasks))

		progressLabel.stringValue = s as String
	}
}
