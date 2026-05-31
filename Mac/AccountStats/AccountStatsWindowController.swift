//
//  AccountStatsWindowController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 4/7/26.
//

import AppKit

final class AccountStatsWindowController: NSWindowController {

	private static let windowIsOpenKey = "AccountStatsWindowIsOpen"

	static private(set) var shouldOpenAtStartup: Bool {
		get {
			UserDefaults.standard.bool(forKey: windowIsOpenKey)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Self.windowIsOpenKey)
		}
	}

	private var hasBeenShown = false

	init() {
		let size = NSSize(width: AccountStatsLayout.windowDefaultWidth, height: AccountStatsLayout.windowDefaultHeight)
		let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: true)
		window.title = NSLocalizedString("Account Stats", comment: "Account Stats window title")
		window.isReleasedWhenClosed = false
		window.minSize = NSSize(width: AccountStatsLayout.windowMinWidth, height: AccountStatsLayout.windowMinHeight)
		window.contentViewController = AccountStatsViewController()
		window.setFrameAutosaveName("AccountStatsWindow")

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
		}
		super.showWindow(sender)
	}

	func saveState() {
		Self.shouldOpenAtStartup = window?.isVisible ?? false
	}
}
