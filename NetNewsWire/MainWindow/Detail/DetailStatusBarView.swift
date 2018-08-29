//
//  DetailStatusBarView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 12/16/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import AppKit
import DB5
import Articles

final class DetailStatusBarView: NSView {

	@IBOutlet var urlLabel: NSTextField!

	private var didConfigureLayer = false
	private var mouseoverLink: String? {
		didSet {
			updateLinkForDisplay()
		}
	}

	private var linkForDisplay: String? {
		didSet {
			needsLayout = true
			if let link = linkForDisplay {
				urlLabel.stringValue = link
				self.isHidden = false
			}
			else {
				urlLabel.stringValue = ""
				self.isHidden = true
			}
		}
	}

	override var isOpaque: Bool {
		return false
	}
	
	override var isFlipped: Bool {
		return true
	}

	override var wantsUpdateLayer: Bool {
		return true
	}

	override func updateLayer() {

		guard !didConfigureLayer else {
			return
		}
		if let layer = layer {
			let color = appDelegate.currentTheme.color(forKey: "MainWindow.Detail.statusBar.backgroundColor")
			layer.backgroundColor = color.cgColor
			layer.cornerRadius = 4.0
			didConfigureLayer = true
		}
	}

	override func awakeFromNib() {

		NotificationCenter.default.addObserver(self, selector: #selector(timelineSelectionDidChange(_:)), name: .TimelineSelectionDidChange, object: nil)

		NotificationCenter.default.addObserver(self, selector: #selector(mouseDidEnterLink(_:)), name: .MouseDidEnterLink, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(mouseDidExitLink(_:)), name: .MouseDidExitLink, object: nil)

		alphaValue = 0.9
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
	}
}

private extension DetailStatusBarView {

	// MARK: URL Label

	func updateLinkForDisplay() {

		if let mouseoverLink = mouseoverLink, !mouseoverLink.isEmpty {
			linkForDisplay = (mouseoverLink as NSString).rs_stringByStrippingHTTPOrHTTPSScheme()
		}
		else {
			linkForDisplay = nil
		}
	}
}


