//
//  WebStatusBarView.swift
//  Multiplatform macOS
//
//  Created by Maurice Parker on 7/8/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import AppKit
import Articles

final class WebStatusBarView: NSView {

	var urlLabel = NSTextField(labelWithString: "")

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

	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		commonInit()
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}
	
	override func updateLayer() {
		guard let layer = layer else {
			return
		}
		if !didConfigureLayerRadius {
			layer.cornerRadius = 4.0
			didConfigureLayerRadius = true
		}
		
		layer.backgroundColor = AppAssets.webStatusBarBackground.cgColor
	}
}

// MARK: - Private

private extension WebStatusBarView {

	func commonInit() {
		self.isHidden = true
		urlLabel.translatesAutoresizingMaskIntoConstraints = false
		urlLabel.lineBreakMode = .byTruncatingMiddle
		urlLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		
		addSubview(urlLabel)
		NSLayoutConstraint.activate([
			leadingAnchor.constraint(equalTo: urlLabel.leadingAnchor, constant: -6),
			trailingAnchor.constraint(equalTo: urlLabel.trailingAnchor, constant: 6),
			centerYAnchor.constraint(equalTo: urlLabel.centerYAnchor)
		])
	}
	
	func updateLinkForDisplay() {
		if let mouseoverLink = mouseoverLink, !mouseoverLink.isEmpty {
			linkForDisplay = mouseoverLink.strippingHTTPOrHTTPSScheme
		}
		else {
			linkForDisplay = nil
		}
	}
}


