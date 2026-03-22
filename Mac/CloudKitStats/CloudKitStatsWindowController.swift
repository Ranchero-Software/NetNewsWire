//
//  CloudKitStatsWindowController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 3/20/26.
//

@preconcurrency import AppKit

@MainActor final class CloudKitStatsWindowController: NSWindowController {

	private static let windowSize = NSSize(width: 400, height: 450)
	private static let frameAutosaveName = "CloudKitStats"

	private var hasBeenShown = false

	init() {
		let window = NSWindow(contentRect: NSRect(origin: .zero, size: Self.windowSize), styleMask: [.titled, .closable], backing: .buffered, defer: true)
		window.title = "iCloud Storage Stats"
		window.isReleasedWhenClosed = false
		window.contentViewController = CloudKitStatsViewController()

		window.representedURL = URL(string: "https://icloud.com")
		if let iconButton = window.standardWindowButton(.documentIconButton) {
			iconButton.image = NSImage(systemSymbolName: "icloud", accessibilityDescription: "iCloud")
		}

		super.init(window: window)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) is not supported")
	}

	override func showWindow(_ sender: Any?) {
		if !hasBeenShown {
			hasBeenShown = true
			window?.center()
			window?.setFrameAutosaveName(Self.frameAutosaveName)
		}
		super.showWindow(sender)
	}
}
