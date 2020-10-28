//
//  ExtensionPointAddTableCellView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/6/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import AppKit

protocol ExtensionPointTableCellViewDelegate: class {
	func addExtensionPoint(_ extensionPointType: ExtensionPoint.Type)
}

class ExtensionPointAddTableCellView: NSTableCellView {

	weak var delegate: ExtensionPointTableCellViewDelegate?
	var extensionPointType: ExtensionPoint.Type?
	
	@IBOutlet weak var templateImageView: NSImageView?
	@IBOutlet weak var titleLabel: NSTextField?
    
	@IBAction func pressed(_ sender: Any) {
		guard let extensionPointType = extensionPointType else { return }
		delegate?.addExtensionPoint(extensionPointType)
	}
	
}
