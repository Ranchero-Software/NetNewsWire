//
//  ExtensionPointMarsEditWindowController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/8/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Cocoa

class ExtensionPointEnableMarsEditWindowController: NSWindowController {

	private weak var hostWindow: NSWindow?

	convenience init() {
		self.init(windowNibName: NSNib.Name("ExtensionPointMarsEdit"))
	}
	
	override func windowDidLoad() {
		super.windowDidLoad()
	}
	
	// MARK: API
	
	func runSheetOnWindow(_ hostWindow: NSWindow) {
		self.hostWindow = hostWindow
		hostWindow.beginSheet(window!)
	}

	// MARK: Actions
	
	@IBAction func cancel(_ sender: Any) {
		hostWindow!.endSheet(window!, returnCode: NSApplication.ModalResponse.cancel)
	}
	
	@IBAction func enable(_ sender: Any) {
		ExtensionPointManager.shared.activateExtensionPoint(ExtensionPointIdentifer.marsEdit)
		hostWindow!.endSheet(window!, returnCode: NSApplication.ModalResponse.OK)
	}

}
