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
	private var isObservingResizeNotifications = false

	/// When the find bar is visible, the web view is pushed below it and no longer
	/// extends under the toolbar, so we should not set obscuredContentInsets.
	var isFindBarVisible = false {
		didSet {
			if isFindBarVisible != oldValue {
				updateObscuredContentInsets()
			}
		}
	}

	private static let estimatedToolbarHeight: CGFloat = 52 // Height of macOS 26.2 icon-only toolbar
	private var toolbarHeight: CGFloat {
		guard let window,
			  let toolbar = window.toolbar,
			  toolbar.isVisible,
			  let contentView = window.contentView else {
			return lastToolbarHeight ?? Self.estimatedToolbarHeight
		}

		let contentLayoutRect = window.contentLayoutRect
		let windowHeight = contentView.bounds.height
		let height = windowHeight - contentLayoutRect.height
		lastToolbarHeight = height
		return height
	}
	private var lastToolbarHeight: CGFloat?

	override init(frame: CGRect, configuration: WKWebViewConfiguration) {
		super.init(frame: frame, configuration: configuration)
		updateObscuredContentInsets()
	}

	required init?(coder: NSCoder) {
		abort()
	}

	override func accessibilityLabel() -> String? {
		NSLocalizedString("Article", comment: "Article")
	}

	// MARK: - NSResponder

	override func keyDown(with event: NSEvent) {
		if keyboardDelegate?.keydown(event, in: self) ?? false {
			return
		}
		super.keyDown(with: event)
	}

	// MARK: - NSView

	override func viewDidMoveToWindow() {
		super.viewDidMoveToWindow()
		updateObscuredContentInsets()

		if let window, !isObservingResizeNotifications {
			NotificationCenter.default.addObserver(
				self,
				selector: #selector(windowDidResize(_:)),
				name: NSWindow.didResizeNotification,
				object: window
			)
			isObservingResizeNotifications = true
		}
	}

	@objc func windowDidResize(_ notification: Notification) {
		updateObscuredContentInsets()
	}

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
	}

	// MARK: NSTextFinderClient

	// Returning false here prevents the "Replace" checkbox from appearing in the find bar
	override var isEditable: Bool { return false }

}

// MARK: - Private

private extension NSUserInterfaceItemIdentifier {
	static let DetailMenuItemIdentifierReload = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierReload")
	static let DetailMenuItemIdentifierOpenLink = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierOpenLink")
}

private extension DetailWebView {
	static let menuItemIdentifiersToHide: [NSUserInterfaceItemIdentifier] = [.DetailMenuItemIdentifierReload]
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

	func updateObscuredContentInsets() {
		// When the find bar is visible, the web view is constrained below it and no longer
		// extends under the toolbar, so we don't need to account for toolbar obscuring.
		let topInset = isFindBarVisible ? 0 : toolbarHeight
		let updatedObscuredContentInsets = NSEdgeInsets(top: topInset, left: 0, bottom: 0, right: 0)
		if obscuredContentInsets != updatedObscuredContentInsets {
			obscuredContentInsets = updatedObscuredContentInsets
		}
	}
}
