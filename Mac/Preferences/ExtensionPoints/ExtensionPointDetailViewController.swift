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
	private var extensionPoint: ExtensionPoint?

	init(extensionPoint: ExtensionPoint) {
		super.init(nibName: "ExtensionPointDetail", bundle: nil)
		self.extensionPoint = extensionPoint
	}

	public required init?(coder: NSCoder) {
		super.init(coder: coder)
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		guard let extensionPoint = extensionPoint else { return }
		imageView.image = extensionPoint.image
		titleLabel.stringValue = extensionPoint.title
		descriptionLabel.attributedStringValue = extensionPoint.description
	}
	
}
