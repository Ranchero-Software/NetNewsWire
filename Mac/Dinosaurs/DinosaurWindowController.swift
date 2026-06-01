//
//  DinosaurWindowController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 5/31/26.
//

@preconcurrency import AppKit
import SwiftUI

final class DinosaurWindowController: NSWindowController {

	init() {
		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 800, height: 500),
			styleMask: [.titled, .closable, .miniaturizable, .resizable],
			backing: .buffered,
			defer: true
		)
		window.title = NSLocalizedString("Dinosaurs", comment: "Dinosaurs window title")
		window.contentMinSize = NSSize(width: 500, height: 300)
		window.contentViewController = NSHostingController(rootView: DinosaursView())
		window.center()

		super.init(window: window)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) is not supported")
	}
}
