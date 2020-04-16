//
//  NSAttributedString+NetNewsWire.swift
//  NetNewsWire
//
//  Created by Nate Weaver on 2020-04-07.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

#if canImport(AppKit)
import AppKit
typealias Font = NSFont
typealias FontDescriptor = NSFontDescriptor
typealias Color = NSColor

private let boldTrait = NSFontDescriptor.SymbolicTraits.bold
private let italicTrait = NSFontDescriptor.SymbolicTraits.italic
private let monoSpaceTrait = NSFontDescriptor.SymbolicTraits.monoSpace
#else
import UIKit
typealias Font = UIFont
typealias FontDescriptor = UIFontDescriptor
typealias Color = UIColor

private let boldTrait = UIFontDescriptor.SymbolicTraits.traitBold
private let italicTrait = UIFontDescriptor.SymbolicTraits.traitItalic
private let monoSpaceTrait = UIFontDescriptor.SymbolicTraits.traitMonoSpace
#endif

extension NSAttributedString {

	func adding(font baseFont: Font, color: Color? = nil) -> NSAttributedString {
		let mutable = self.mutableCopy() as! NSMutableAttributedString
		let fullRange = NSRange(location: 0, length: mutable.length)

		if let color = color {
			mutable.addAttribute(.foregroundColor, value: color as Any, range: fullRange)
		}

		let size = baseFont.pointSize
		let baseDescriptor = baseFont.fontDescriptor
		let baseSymbolicTraits = baseDescriptor.symbolicTraits

		let baseTraits = baseDescriptor.object(forKey: .traits) as! [FontDescriptor.TraitKey: Any]
		let baseWeight = baseTraits[.weight] as! Font.Weight

		mutable.enumerateAttribute(.font, in: fullRange, options: []) { (font: Any?, range: NSRange, stop: UnsafeMutablePointer<ObjCBool>) in
			guard let font = font as? Font else { return }

			var newSymbolicTraits = baseSymbolicTraits

			let symbolicTraits = font.fontDescriptor.symbolicTraits

			if symbolicTraits.contains(italicTrait) {
				newSymbolicTraits.insert(italicTrait)
			}

			if symbolicTraits.contains(monoSpaceTrait) {
				newSymbolicTraits.insert(monoSpaceTrait)
			}

			#if canImport(AppKit)
			var descriptor = baseDescriptor.withSymbolicTraits(newSymbolicTraits)
			#else
			var descriptor = baseDescriptor.withSymbolicTraits(newSymbolicTraits)!
			#endif

			if symbolicTraits.contains(boldTrait) {
				// If the base font is semibold (as timeline titles are), make the "bold"
				// text heavy for better contrast.

				if baseWeight == .semibold {
					let traits: [FontDescriptor.TraitKey: Any] = [.weight: Font.Weight.heavy]
					let attributes: [FontDescriptor.AttributeName: Any] = [.traits: traits]
					descriptor = descriptor.addingAttributes(attributes)
				}
			}

			let newFont = Font(descriptor: descriptor, size: size)

			mutable.addAttribute(.font, value: newFont as Any, range: range)
		}

		// make sup/sub smaller. `Key("NSSupeScript")` is used here because `.superscript`
		// isn't defined in UIKit.
		let superscriptAttribute = Key("NSSuperScript")

		mutable.enumerateAttributes(in: fullRange, options: []) { (attributes: [Key : Any], range: NSRange, stop: UnsafeMutablePointer<ObjCBool>) in
			guard let superscript = attributes[superscriptAttribute] as? Int else {
				return
			}

			if superscript != 0 {
				let font = mutable.attribute(.font, at: range.location, effectiveRange: nil) as! Font

				// There's some discrepancy here: The raw value of AppKit's .typeIdentifier is UIKit's .featureIdentifier,
				// and AppKit's .selectorIdentifier is UIKit's .typeIdentifier
				#if canImport(AppKit)
				let features: [FontDescriptor.FeatureKey: Any] = [.typeIdentifier: kVerticalPositionType, .selectorIdentifier: superscript > 0 ? kSuperiorsSelector : kInferiorsSelector]
				#else
				let features: [FontDescriptor.FeatureKey: Any] = [.featureIdentifier: kVerticalPositionType, .typeIdentifier: superscript > 0 ? kSuperiorsSelector : kInferiorsSelector]
				#endif
				let attributes: [FontDescriptor.AttributeName: Any] = [.featureSettings: [features]]
				let descriptor = font.fontDescriptor.addingAttributes(attributes)

				let newFont = Font(descriptor: descriptor, size: font.pointSize)

				let newAttributes: [NSAttributedString.Key: Any] = [
					.font: newFont as Any,
					superscriptAttribute: 0,
				]

				mutable.addAttributes(newAttributes, range: range)
			}
		}

		return mutable.copy() as! NSAttributedString
	}

	convenience init(html: String) {
		let data = html.data(using: .utf8)!
		let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [.characterEncoding: String.Encoding.utf8.rawValue, .documentType: NSAttributedString.DocumentType.html]
		try! self.init(data: data, options: options, documentAttributes: nil)
	}

}
