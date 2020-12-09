//
//  AccountCell.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 11/19/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import AppKit

class AccountCell: NSTableCellView {
	
	private var originalImage: NSImage?
	
	var isImageTemplateCapable = true
	
	override func prepareForReuse() {
		originalImage = nil
	}
	
	override var backgroundStyle: NSView.BackgroundStyle {
		didSet {
			updateImage()
		}
	}
	
}

private extension AccountCell {
	
	func updateImage() {
		guard isImageTemplateCapable else { return }
		
		if backgroundStyle != .normal {
			guard !(imageView?.image?.isTemplate ?? false) else { return }
			
			originalImage = imageView?.image
			
			let templateImage = imageView?.image?.copy() as? NSImage
			templateImage?.isTemplate = true
			imageView?.image = templateImage
		} else {
			guard let originalImage = originalImage else { return }
			imageView?.image = originalImage
		}
	}
	
}
