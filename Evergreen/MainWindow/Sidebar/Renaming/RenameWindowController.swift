//
//  RenameWindowController.swift
//  Evergreen
//
//  Created by Brent Simmons on 1/28/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit

final class RenameWindowController: NSWindowController {

	@IBOutlet var renamePrompt: NSTextField!
	@IBOutlet var newTitleTextField: NSTextField!
	@IBOutlet var renameButton: NSButton!
	
	private var originalTitle: String!

	public convenience init(originalTitle: String) {

		self.init(windowNibName: NSNib.Name(rawValue: "RenameSheet"))
		self.originalTitle = originalTitle
	}
}
