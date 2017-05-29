//
//  StatusBarView.swift
//  Evergreen
//
//  Created by Brent Simmons on 9/17/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Cocoa
import RSCore
import DataModel
import RSWeb

final class StatusBarView: NSView {

	@IBOutlet var progressIndicator: NSProgressIndicator!
	@IBOutlet var progressLabel: NSTextField!
	@IBOutlet var urlLabel: NSTextField!
	
	fileprivate var isAnimatingProgress = false
	fileprivate var article: Article? {
		didSet {
			updateURLLabel()
		}
	}
	
	override var isFlipped: Bool {
		get {
			return true
		}
	}

	override func awakeFromNib() {

		let progressLabelFontSize = progressLabel.font?.pointSize ?? 13.0
		progressLabel.font = NSFont.monospacedDigitSystemFont(ofSize: progressLabelFontSize, weight: NSFontWeightRegular)
		progressLabel.stringValue = ""		
		
		NotificationCenter.default.addObserver(self, selector: #selector(progressDidChange(_:)), name: .AccountRefreshProgressDidChange, object: nil)

		NotificationCenter.default.addObserver(self, selector: #selector(timelineSelectionDidChange(_:)), name: .TimelineSelectionDidChange, object: nil)
	}

	// MARK: Notifications

	dynamic func progressDidChange(_ notification: Notification) {

		guard let progress = notification.userInfo?[progressKey] as? DownloadProgress else {
			return
		}
		updateProgressIndicator(progress)
		updateProgressLabel(progress)
	}

	// MARK: Notifications
	
	dynamic func timelineSelectionDidChange(_ note: Notification) {
		
		let timelineView = note.userInfo?[viewKey] as! NSView
		
		if timelineView.window! === self.window {
			article = note.userInfo?[articleKey] as? Article
		}
	}

	// MARK: Drawing

	private let lineColor = NSColor(calibratedWhite: 0.57, alpha: 1.0)

	override func draw(_ dirtyRect: NSRect) {

		let path = NSBezierPath()
		path.lineWidth = 1.0
		path.move(to: NSPoint(x: NSMinX(bounds), y: NSMinY(bounds) + 0.5))
		path.line(to: NSPoint(x: NSMaxX(bounds), y: NSMinY(bounds) + 0.5))
		lineColor.set()
		path.stroke()
	}
}

private extension StatusBarView {

	// MARK: URL Label
	
	func updateURLLabel() {
		
		needsLayout = true
		
		guard let article = article else {
			urlLabel.stringValue = ""
			return
		}
		
		let s = preferredLink(for: article)
		if let s = s {
			urlLabel.stringValue = (s as NSString).rs_stringByStrippingHTTPOrHTTPSScheme()
		}
		else {
			urlLabel.stringValue = ""
		}
	}
	
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

	func updateProgressIndicator(_ progress: DownloadProgress) {

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

	func updateProgressLabel(_ progress: DownloadProgress) {

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
