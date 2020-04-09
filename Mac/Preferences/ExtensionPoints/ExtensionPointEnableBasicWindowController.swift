//
//  ExtensionPointEnableBasicWindowController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/8/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Cocoa

class ExtensionPointEnableBasicWindowController: NSWindowController {

	@IBOutlet weak var imageView: NSImageView!
	@IBOutlet weak var titleLabel: NSTextField!
	@IBOutlet weak var descriptionLabel: NSTextField!
	
	var extensionPointType: ExtensionPointType?
	private weak var hostWindow: NSWindow?
	
	convenience init() {
		self.init(windowNibName: NSNib.Name("ExtensionPointEnableBasic"))
	}
	
	override func windowDidLoad() {
		super.windowDidLoad()
		guard let extensionPointType = extensionPointType else { return }
		
		imageView.image = extensionPointType.templateImage
		titleLabel.stringValue = extensionPointType.title
		descriptionLabel.attributedStringValue = extensionPointType.description
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
		guard let extensionPointType = extensionPointType else { return }
		
		switch extensionPointType {
		case .marsEdit:
			ExtensionPointManager.shared.activateExtensionPoint(ExtensionPointIdentifer.marsEdit)
		case .microblog:
			ExtensionPointManager.shared.activateExtensionPoint(ExtensionPointIdentifer.microblog)
		default:
			assertionFailure("Unknown extension point.")
		}
		
		hostWindow!.endSheet(window!, returnCode: NSApplication.ModalResponse.OK)
	}

}
