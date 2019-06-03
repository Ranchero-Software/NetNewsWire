//
//  DetailStatusBarView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 12/16/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import AppKit
import Articles

final class DetailStatusBarView: NSView {

	@IBOutlet var urlLabel: NSTextField!

	var mouseoverLink: String? {
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

	private var didConfigureLayerRadius = false

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
		guard let layer = layer else {
			return
		}
		if !didConfigureLayerRadius {
			layer.cornerRadius = 4.0
			didConfigureLayerRadius = true
		}

		let color = self.effectiveAppearance.isDarkMode ? NSColor.textBackgroundColor : NSColor(named: "DetailStatusBarBackground")!
		layer.backgroundColor = color.cgColor
	}
}

// MARK: - Private

private extension DetailStatusBarView {

	func updateLinkForDisplay() {
		if let mouseoverLink = mouseoverLink, !mouseoverLink.isEmpty {
			linkForDisplay = (mouseoverLink as NSString).rs_stringByStrippingHTTPOrHTTPSScheme()
		}
		else {
			linkForDisplay = nil
		}
	}
}


