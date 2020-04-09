//
//  ExtensionPointType.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/8/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore

enum ExtensionPointType {
	case marsEdit
	case microblog
	case twitter

	var isSinglton: Bool {
		switch self {
		case .marsEdit, .microblog:
			return true
		default:
			return false
		}
	}
	
	var title: String {
		switch self {
		case .marsEdit:
			return NSLocalizedString("MarsEdit", comment: "MarsEdit")
		case .microblog:
			return NSLocalizedString("Micro.blog", comment: "Micro.blog")
		case .twitter:
			return NSLocalizedString("Twitter", comment: "Twitter")
		}

	}

	var templateImage: RSImage {
		switch self {
		case .marsEdit:
			return AppAssets.extensionPointMarsEdit
		case .microblog:
			return AppAssets.extensionPointMicroblog
		case .twitter:
			return AppAssets.extensionPointTwitter
		}
	}

	var description: NSAttributedString {
		switch self {
		case .marsEdit:
			let attrString = makeAttrString("This extension enables share menu functionality to send selected article text to MarsEdit.  You need the MarsEdit application for this to work.")
			let range = NSRange(location: 81, length: 8)
			attrString.beginEditing()
			attrString.addAttribute(NSAttributedString.Key.link, value: "https://red-sweater.com/marsedit/", range: range)
			attrString.addAttribute(NSAttributedString.Key.foregroundColor, value: NSColor.systemBlue, range: range)
			attrString.endEditing()
			return attrString
		case .microblog:
			let attrString = makeAttrString("This extension enables share menu functionality to send selected article text to Micro.blog.  You need the Micro.blog application for this to work.")
			let range = NSRange(location: 81, length: 10)
			attrString.beginEditing()
			attrString.addAttribute(NSAttributedString.Key.link, value: "https://micro.blog", range: range)
			attrString.addAttribute(NSAttributedString.Key.foregroundColor, value: NSColor.systemBlue, range: range)
			attrString.endEditing()
			return attrString
		case .twitter:
			let attrString = makeAttrString("This extension enables you to subscribe to Twitter URL's as if they were RSS feeds.")
			let range = NSRange(location: 43, length: 7)
			attrString.beginEditing()
			attrString.addAttribute(NSAttributedString.Key.link, value: "https://twitter.com", range: range)
			attrString.addAttribute(NSAttributedString.Key.foregroundColor, value: NSColor.systemBlue, range: range)
			attrString.endEditing()
			return attrString
		}
	}
	
}

private extension ExtensionPointType {
	
	func makeAttrString(_ text: String) -> NSMutableAttributedString {
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
