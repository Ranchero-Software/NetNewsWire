//
//  ExtensionPointDetailViewController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/8/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Cocoa

class ExtensionPointDetailViewController: NSViewController {

	@IBOutlet weak var imageView: NSImageView!
	@IBOutlet weak var titleLabel: NSTextField!
	@IBOutlet weak var descriptionLabel: NSTextField!
	
	private var extensionPointWindowController: NSWindowController?
	private var extensionPointID: ExtensionPointIdentifer?

	init(extensionPointID: ExtensionPointIdentifer) {
		super.init(nibName: "ExtensionPointDetail", bundle: nil)
		self.extensionPointID = extensionPointID
	}

	public required init?(coder: NSCoder) {
		super.init(coder: coder)
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		guard let extensionPointID = extensionPointID else { return }
		imageView.image = extensionPointID.templateImage
		titleLabel.stringValue = extensionPointID.title
		descriptionLabel.attributedStringValue = extensionPointID.description
	}
	
}
