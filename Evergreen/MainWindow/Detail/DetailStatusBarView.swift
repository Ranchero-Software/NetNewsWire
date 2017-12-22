//
//  DetailStatusBarView.swift
//  Evergreen
//
//  Created by Brent Simmons on 12/16/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Cocoa
import DB5
import Data

final class DetailStatusBarView: NSView {

	@IBOutlet var urlLabel: NSTextField!

//	private var didConfigureLayer = false

	private var article: Article? {
		didSet {
			updateURLLabel()
		}
	}
	private var mouseoverLink: String? {
		didSet {
			updateURLLabel()
		}
	}

	private let backgroundColor = appDelegate.currentTheme.color(forKey: "MainWindow.Detail.statusBar.backgroundColor")

	override var isFlipped: Bool {
		return true
	}

//	override var wantsUpdateLayer: Bool {
//		return true
//	}
//
//	override func updateLayer() {
//
//		guard !didConfigureLayer else {
//			return
//		}
//		if let layer = layer {
//			let color = appDelegate.currentTheme.color(forKey: "MainWindow.Detail.statusBar.backgroundColor")
//			layer.backgroundColor = color.cgColor
//			didConfigureLayer = true
//		}
//	}

	override func awakeFromNib() {

		NotificationCenter.default.addObserver(self, selector: #selector(timelineSelectionDidChange(_:)), name: .TimelineSelectionDidChange, object: nil)

		NotificationCenter.default.addObserver(self, selector: #selector(mouseDidEnterLink(_:)), name: .MouseDidEnterLink, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(mouseDidExitLink(_:)), name: .MouseDidExitLink, object: nil)
	}

	// MARK: - Notifications

	@objc func mouseDidEnterLink(_ notification: Notification) {

		guard let userInfo = notification.userInfo, let view = userInfo[UserInfoKey.view] as? NSView, window === view.window else {
			return
		}
		guard let link = userInfo[UserInfoKey.url] as? String else {
			return
		}
		mouseoverLink = link
	}

	@objc func mouseDidExitLink(_ notification: Notification) {

		guard let view = notification.userInfo?[UserInfoKey.view] as? NSView, window === view.window else {
			return
		}
		mouseoverLink = nil
	}

	@objc func timelineSelectionDidChange(_ notification: Notification) {

		guard let view = notification.userInfo?[UserInfoKey.view] as? NSView, window === view.window else {
			return
		}
		mouseoverLink = nil
		article = notification.userInfo?[UserInfoKey.article] as? Article
	}

	// MARK: Drawing

	private let lineColor = NSColor(calibratedWhite: 0.85, alpha: 1.0)

	override func draw(_ dirtyRect: NSRect) {

		backgroundColor.set()
		dirtyRect.fill()

		let path = NSBezierPath()
		path.lineWidth = 1.0
		path.move(to: NSPoint(x: NSMinX(bounds), y: NSMinY(bounds) + 0.5))
		path.line(to: NSPoint(x: NSMaxX(bounds), y: NSMinY(bounds) + 0.5))
		lineColor.set()
		path.stroke()
	}
}

private extension DetailStatusBarView {

	// MARK: URL Label

	func updateURLLabel() {

		needsLayout = true

		guard let article = article else {
			setURLLabel("")
			return
		}

		if let mouseoverLink = mouseoverLink, !mouseoverLink.isEmpty {
			setURLLabel(mouseoverLink)
			return
		}

		if let s = article.preferredLink {
			setURLLabel(s)
		}
		else {
			setURLLabel("")
		}
	}

	func setURLLabel(_ link: String) {

		urlLabel.stringValue = (link as NSString).rs_stringByStrippingHTTPOrHTTPSScheme()
	}
}


