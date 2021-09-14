//
//  DetailWebView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/10/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import WebKit
import RSCore

final class DetailWebView: WKWebView {

	weak var keyboardDelegate: KeyboardDelegate?
	
	override func accessibilityLabel() -> String? {
		return NSLocalizedString("Article", comment: "Article")
	}

	// MARK: - NSResponder
	
	override func keyDown(with event: NSEvent) {
		if keyboardDelegate?.keydown(event, in: self) ?? false {
			return
		}
		super.keyDown(with: event)
	}

	// MARK: NSView

	override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
		// There’s no API for affecting a WKWebView’s contextual menu.
		// (WebView had API for this.)
		//
		// This a minor hack. It hides unwanted menu items.
		// The menu item identifiers are not documented anywhere;
		// they could change, and this code would need updating.
		for menuItem in menu.items {
			if shouldHideMenuItem(menuItem) {
				menuItem.isHidden = true
			}
		}

		super.willOpenMenu(menu, with: event)
	}

	override func viewWillStartLiveResize() {
		super.viewWillStartLiveResize()
		evaluateJavaScript("document.body.style.overflow = 'hidden';", completionHandler: nil)
	}

	override func viewDidEndLiveResize() {
		super.viewDidEndLiveResize()
		evaluateJavaScript("document.body.style.overflow = 'visible';", completionHandler: nil)
		bigSurOffsetFix()
	}
	
	override func setFrameSize(_ newSize: NSSize) {
		super.setFrameSize(newSize)
		if (!inLiveResize) {
			bigSurOffsetFix()
		}
	}
		
	private var inBigSurOffsetFix = false
	
	private func bigSurOffsetFix() {
		/*
		On macOS 11, when a user exits full screen
		or exits zoomed mode by disconnecting an external display
		the webview's `origin.y` is offset by a sizeable amount.
		
		This code adjusts the height of the window by -1pt/+1pt,
		which puts the webview back in the correct place.
		*/
		if #available(macOS 11, *) {
			guard var frame = window?.frame else {
				return
			}

			guard !inBigSurOffsetFix else {
				return
			}
			
			inBigSurOffsetFix = true
			
			defer {
				inBigSurOffsetFix = false
			}

			frame.size = NSSize(width: window!.frame.width, height: window!.frame.height - 1)
			window!.setFrame(frame, display: false)
			frame.size = NSSize(width: window!.frame.width, height: window!.frame.height + 1)
			window!.setFrame(frame, display: false)
		}
	}
}

// MARK: - Private

private extension NSUserInterfaceItemIdentifier {

	static let DetailMenuItemIdentifierReload = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierReload")
	static let DetailMenuItemIdentifierOpenLink = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierOpenLink")
}

private extension DetailWebView {

	static let menuItemIdentifiersToHide: [NSUserInterfaceItemIdentifier] = [.DetailMenuItemIdentifierReload, .DetailMenuItemIdentifierOpenLink]
	static let menuItemIdentifierMatchStrings = ["newwindow", "download"]

	func shouldHideMenuItem(_ menuItem: NSMenuItem) -> Bool {

		guard let identifier = menuItem.identifier else {
			return false
		}

		if DetailWebView.menuItemIdentifiersToHide.contains(identifier) {
			return true
		}

		let lowerIdentifier = identifier.rawValue.lowercased()
		for matchString in DetailWebView.menuItemIdentifierMatchStrings {
			if lowerIdentifier.contains(matchString) {
				return true
			}
		}

		return false
	}
}

