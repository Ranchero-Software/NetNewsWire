//
//  NSAttributedString+NetNewsWire.swift
//  NetNewsWire
//
//  Created by Nate Weaver on 2020-04-07.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import AppKit

extension NSAttributedString {

	func adding(font baseFont: NSFont, color: NSColor? = nil) -> NSAttributedString {
		let mutable = self.mutableCopy() as! NSMutableAttributedString
		let fullRange = NSRange(location: 0, length: mutable.length)

		if let color = color {
			mutable.addAttribute(.foregroundColor, value: color as Any, range: fullRange)
		}

		let size = baseFont.pointSize
		let baseDescriptor = baseFont.fontDescriptor
		let traits = baseDescriptor.symbolicTraits

		mutable.enumerateAttribute(.font, in: fullRange, options: []) { (font: Any?, range: NSRange, stop: UnsafeMutablePointer<ObjCBool>) in
			guard let font = font as? NSFont else { return }

			var newTraits = traits

			if font.fontDescriptor.symbolicTraits.contains(.italic) {
				newTraits.insert(.italic)
			}

			var descriptor = baseDescriptor.withSymbolicTraits(newTraits)

			if font.fontDescriptor.symbolicTraits.contains(.bold) {
				// This currently assumes we're modifying the title field, which is
				// already semibold.
				let traits: [NSFontDescriptor.TraitKey: Any] = [.weight: NSFont.Weight.heavy]
				let attributes: [NSFontDescriptor.AttributeName: Any] = [.traits: traits]
				descriptor = descriptor.addingAttributes(attributes)
			}

			let newFont = NSFont(descriptor: descriptor, size: size)

			mutable.addAttribute(.font, value: newFont as Any, range: range)
		}

		// make sup/sub smaller
		mutable.enumerateAttributes(in: fullRange, options: []) { (attributes: [Key : Any], range: NSRange, stop: UnsafeMutablePointer<ObjCBool>) in
			guard let superscript = attributes[.superscript] as? Int else {
				return
			}

			if superscript != 0 {
				let font = mutable.attribute(.font, at: range.location, effectiveRange: nil) as! NSFont
				let size = font.pointSize * 0.6

				let newFont = NSFont(descriptor: font.fontDescriptor, size: size)
				mutable.addAttribute(.font, value: newFont as Any, range: range)
			}

		}

		return mutable.copy() as! NSAttributedString
	}

}
