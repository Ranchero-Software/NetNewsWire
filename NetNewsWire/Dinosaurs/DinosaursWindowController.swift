//
//  DinosaursWindowController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/12/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import AppKit

class DinosaursWindowController: NSWindowController {

	convenience init() {

		self.init(windowNibName: NSNib.Name(rawValue: "DinosaursWindow"))
	}

    override func windowDidLoad() {

    }

	// MARK: - Actions

	@IBAction func openHomePage(_ sender: Any?) {

	}

	@IBAction func selectInMainWindow(_ sender: Any?) {

	}

	@IBAction func unsubscribe(_ sender: Any?) {
		
	}
}
