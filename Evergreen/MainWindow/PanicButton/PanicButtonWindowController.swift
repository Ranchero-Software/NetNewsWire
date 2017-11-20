//
//  PanicButtonWindowController.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/16/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Cocoa

final class PanicButtonWindowController: NSWindowController {

	var hostWindow: NSWindow?

	convenience init() {

		self.init(windowNibName: NSNib.Name(rawValue: "PanicButtonWindow"))
	}

	func runSheetOnWindow(_ w: NSWindow) {

		hostWindow = w
		hostWindow!.beginSheet(window!) { (returnCode: NSApplication.ModalResponse) -> Void in
		}
	}

	private func closeSheet(_ response: NSApplication.ModalResponse) {

		hostWindow!.endSheet(window!, returnCode: response)
	}

	// MARK: - Actions

	@IBAction func cancel(_ sender: AnyObject) {

		closeSheet(.cancel)
	}

	@IBAction func performPanic(_ sender: AnyObject) {

		closeSheet(.OK)
	}
}
