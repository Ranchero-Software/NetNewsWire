//
//  AboutWindowController.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 03/10/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import AppKit
import SwiftUI
import RSCore

extension NSUserInterfaceItemIdentifier {
	static let aboutNetNewsWire = NSUserInterfaceItemIdentifier("about.netnewswire")
}

// MARK: - AboutWindowController

@available(macOS 12, *)
class AboutWindowController: NSWindowController {
	
	var hostingController: AboutHostingController
	
	override init(window: NSWindow?) {
		self.hostingController = AboutHostingController(rootView: AnyView(AboutNewNewsWireView()))
		super.init(window: window)
		let window = NSWindow(contentViewController: hostingController)
		window.identifier = .aboutNetNewsWire
		window.standardWindowButton(.zoomButton)?.isEnabled = false
		window.standardWindowButton(.miniaturizeButton)?.isEnabled = false
		window.titleVisibility = .hidden
		self.window = window
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func windowDidLoad() {
		super.windowDidLoad()
	}
	
}

// MARK: - AboutHostingController

@available(macOS 12, *)
class AboutHostingController: NSHostingController<AnyView> {
	
	override init(rootView: AnyView) {
		super.init(rootView: rootView)
	}
	
	@MainActor required dynamic init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}



