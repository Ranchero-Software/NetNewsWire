//
//  ExtensionPoint.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore

protocol ExtensionPoint {

	static var isSinglton: Bool { get }
	static var title: String { get }
	static var templateImage: RSImage { get }
	static var description: NSAttributedString { get }
	
	var extensionPointID: ExtensionPointIdentifer { get }
	
}

extension ExtensionPoint {
	
	var title: String {
		return extensionPointID.title
	}

	static func makeAttrString(_ text: String) -> NSMutableAttributedString {
		let paragraphStyle = NSMutableParagraphStyle()
		paragraphStyle.alignment = .center

		let attrs = [
			NSAttributedString.Key.paragraphStyle: paragraphStyle,
			NSAttributedString.Key.font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
			NSAttributedString.Key.foregroundColor: NSColor.textColor
		]

		return NSMutableAttributedString(string: text, attributes: attrs)
	}
	
}
