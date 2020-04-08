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
		let symbolicTraits = baseDescriptor.symbolicTraits

		mutable.enumerateAttribute(.font, in: fullRange, options: []) { (font: Any?, range: NSRange, stop: UnsafeMutablePointer<ObjCBool>) in
			guard let font = font as? NSFont else { return }

			var newSymbolicTraits = symbolicTraits

			if font.fontDescriptor.symbolicTraits.contains(.italic) {
				newSymbolicTraits.insert(.italic)
			}

			var descriptor = baseDescriptor.withSymbolicTraits(newSymbolicTraits)

			if font.fontDescriptor.symbolicTraits.contains(.bold) {
				let baseTraits = baseDescriptor.object(forKey: .traits) as! [NSFontDescriptor.TraitKey: Any]
				let baseWeight = baseTraits[.weight] as! NSFont.Weight

				// If the base font is semibold (as timeline titles are), make the "bold"
				// text heavy for better contrast.

				if baseWeight == .semibold {
					let traits: [NSFontDescriptor.TraitKey: Any] = [.weight: NSFont.Weight.heavy]
					let attributes: [NSFontDescriptor.AttributeName: Any] = [.traits: traits]
					descriptor = descriptor.addingAttributes(attributes)
				}
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

				let features: [NSFontDescriptor.FeatureKey: Any] = [.typeIdentifier: kVerticalPositionType, .selectorIdentifier: superscript > 0 ? kSuperiorsSelector : kInferiorsSelector]
				let attributes: [NSFontDescriptor.AttributeName: Any] = [.featureSettings: [features]]
				let descriptor = font.fontDescriptor.addingAttributes(attributes)

				let newFont = NSFont(descriptor: descriptor, size: font.pointSize)
				mutable.addAttribute(.font, value: newFont as Any, range: range)
				mutable.addAttribute(.superscript, value: 0, range: range)
			}

		}

		return mutable.copy() as! NSAttributedString
	}

}
