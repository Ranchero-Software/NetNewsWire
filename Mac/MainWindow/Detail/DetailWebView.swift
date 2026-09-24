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

	private static let estimatedToolbarHeight: CGFloat = 52 // Height of macOS 26.2 icon-only toolbar

	// How much of the web view sits under the titlebar and toolbar: the toolbar height when the article view
	// is beside the timeline, zero when it’s below the timeline in column layout.
	private var obscuredTopInset: CGFloat {
		guard let window, let toolbar = window.toolbar, toolbar.isVisible, superview != nil else {
			return lastObscuredTopInset ?? Self.estimatedToolbarHeight
		}

		let frameInWindow = convert(bounds, to: nil)
		let inset = max(0.0, frameInWindow.maxY - window.contentLayoutRect.maxY)
		lastObscuredTopInset = inset
		return inset
	}
	private var lastObscuredTopInset: CGFloat?

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

	override func layout() {
		super.layout()
		// The frame moves when the layout switches or the split view divider is dragged.
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
}

// MARK: - Private

private extension NSUserInterfaceItemIdentifier {
	static let DetailMenuItemIdentifierReload = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierReload")
	static let DetailMenuItemIdentifierOpenLink = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierOpenLink")
	static let DetailMenuItemIdentifierGoBack = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierGoBack")
	static let DetailMenuItemIdentifierGoForward = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierGoForward")
}

private extension DetailWebView {
	static let menuItemIdentifiersToHide: [NSUserInterfaceItemIdentifier] = [.DetailMenuItemIdentifierReload, .DetailMenuItemIdentifierGoBack, .DetailMenuItemIdentifierGoForward]
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
		if #available(macOS 26.0, *) {
			let updatedObscuredContentInsets = NSEdgeInsets(top: obscuredTopInset, left: 0, bottom: 0, right: 0)
			if obscuredContentInsets != updatedObscuredContentInsets {
				obscuredContentInsets = updatedObscuredContentInsets
			}
		}
	}
}
