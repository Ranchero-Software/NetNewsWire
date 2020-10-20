//
//  NSAttributedString+NetNewsWire.swift
//  NetNewsWire
//
//  Created by Nate Weaver on 2020-04-07.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import RSParser

#if canImport(AppKit)
import AppKit
typealias Font = NSFont
typealias FontDescriptor = NSFontDescriptor

private let boldTrait = NSFontDescriptor.SymbolicTraits.bold
private let italicTrait = NSFontDescriptor.SymbolicTraits.italic
private let monoSpaceTrait = NSFontDescriptor.SymbolicTraits.monoSpace
#else
import UIKit
typealias Font = UIFont
typealias FontDescriptor = UIFontDescriptor

private let boldTrait = UIFontDescriptor.SymbolicTraits.traitBold
private let italicTrait = UIFontDescriptor.SymbolicTraits.traitItalic
private let monoSpaceTrait = UIFontDescriptor.SymbolicTraits.traitMonoSpace
#endif

extension NSAttributedString {

	/// Adds a font and color to an attributed string.
	///
	/// - Parameters:
	///   - baseFont: The font to add.
	func adding(font baseFont: Font) -> NSAttributedString {
		let mutable = self.mutableCopy() as! NSMutableAttributedString
		let fullRange = NSRange(location: 0, length: mutable.length)

		let size = baseFont.pointSize
		let baseDescriptor = baseFont.fontDescriptor
		let baseSymbolicTraits = baseDescriptor.symbolicTraits

		mutable.enumerateAttribute(.font, in: fullRange, options: []) { (font: Any?, range: NSRange, stop: UnsafeMutablePointer<ObjCBool>) in
			guard let font = font as? Font else { return }

			let currentDescriptor = font.fontDescriptor
			let symbolicTraits = baseSymbolicTraits.union(currentDescriptor.symbolicTraits)

			var descriptor = currentDescriptor.addingAttributes(baseDescriptor.fontAttributes)

			#if canImport(AppKit)
			descriptor = descriptor.withSymbolicTraits(symbolicTraits)
			#else
			descriptor = descriptor.withSymbolicTraits(symbolicTraits)!
			#endif

			let newFont = Font(descriptor: descriptor, size: size)

			mutable.addAttribute(.font, value: newFont as Any, range: range)
		}

		return mutable.copy() as! NSAttributedString
	}

	private enum InTag {
		case none
		case opening
		case closing
	}

	private enum Style {
		case bold
		case italic
		case superscript
		case `subscript`
		case underline
		case strikethrough
		case monospace

		init?(forTag: String) {
			switch forTag {
				case "b", "strong":
					self = .bold
				case "i", "em", "cite", "var", "dfn":
					self = .italic
				case "sup":
					self = .superscript
				case "sub":
					self = .subscript
				case "u", "ins":
					self = .underline
				case "s", "del":
					self = .strikethrough
				case "code", "samp", "tt", "kbd":
					self = .monospace
				default:
					return nil
			}
		}
	}

	/// Returns an attributed string initialized from  HTML text containing basic inline stylistic tags.
	///
	/// - Parameters:
	///   - html: The HTML text.
	///   - locale: The locale used for quotation marks when parsing `<q>` tags.
	convenience init(html: String, locale: Locale = Locale.current) {
		let baseFont = Font.systemFont(ofSize: Font.systemFontSize)

		var inTag: InTag = .none
		var tag = ""
		var currentStyles = CountedSet<Style>()

		var iterator = html.makeIterator()

		let result = NSMutableAttributedString()

		var attributeRanges = [ (range: NSRange, styles: CountedSet<Style>) ]()
		var quoteDepth = 0

		while let char = iterator.next() {
			if char == "<" && inTag == .none {
				tag.removeAll()

				guard let first = iterator.next() else { break }

				if first == "/" {
					inTag = .closing
				} else {
					inTag = .opening
					tag.append(first)
				}
			} else if char == ">" && inTag != .none {
				let lastRange = attributeRanges.last?.range
				let location = lastRange != nil ? lastRange!.location + lastRange!.length : 0
				let range = NSRange(location: location, length: result.mutableString.length - location)

				attributeRanges.append( (range: range, styles: currentStyles) )

				if inTag == .opening {
					if tag == "q" {
						quoteDepth += 1
						let delimiter = quoteDepth % 2 == 1 ? locale.quotationBeginDelimiter : locale.alternateQuotationBeginDelimiter
						result.mutableString.append(delimiter ?? "\"")
					}

					if let style = Style(forTag: tag) {
						currentStyles.insert(style)
					}
				} else {
					if tag == "q" {
						let delimiter = quoteDepth % 2 == 1 ? locale.quotationEndDelimiter : locale.alternateQuotationEndDelimiter
						result.mutableString.append(delimiter ?? "\"")
						quoteDepth -= 1
					}

					if let style = Style(forTag: tag) {
						currentStyles.remove(style)
					}
				}

				inTag = .none
			} else if inTag != .none {
				tag.append(char)
			} else {
				if char == "&" {
					var entity = "&"
					var lastchar: Character? = nil

					while let entitychar = iterator.next() {
						if entitychar.isWhitespace {
							lastchar = entitychar
							break;
						}

						entity.append(entitychar)

						if (entitychar == ";") { break }
					}


					result.mutableString.append(entity.decodedEntity)

					if let lastchar = lastchar { result.mutableString.append(String(lastchar)) }
				} else {
					result.mutableString.append(String(char))
				}
			}
		}

		result.addAttribute(.font, value: baseFont, range: NSRange(location: 0, length: result.length))

		for (range, styles) in attributeRanges {
			if range.location >= result.length { continue }

			let currentFont = result.attribute(.font, at: range.location, effectiveRange: nil) as! Font
			let currentDescriptor = currentFont.fontDescriptor
			var descriptor = currentDescriptor.copy() as! FontDescriptor

			var symbolicTraits = currentDescriptor.symbolicTraits

			if styles.contains(.bold) {
				let traits: [FontDescriptor.TraitKey: Any] = [.weight: Font.Weight.bold]
				let attributes: [FontDescriptor.AttributeName: Any] = [.traits: traits]
				descriptor = descriptor.addingAttributes(attributes)
				symbolicTraits.insert(boldTrait)
			}

			if styles.contains(.italic) {
				symbolicTraits.insert(italicTrait)
			}

			if styles.contains(.monospace) {
				symbolicTraits.insert(monoSpaceTrait)
			}

			#if canImport(AppKit)
			descriptor = descriptor.withSymbolicTraits(symbolicTraits)
			#else
			descriptor = descriptor.withSymbolicTraits(symbolicTraits)!
			#endif

			func verticalPositionFeature(forSuperscript: Bool) -> [FontDescriptor.FeatureKey: Any] {
				#if canImport(AppKit)
				let features: [FontDescriptor.FeatureKey: Any] = [.typeIdentifier: kVerticalPositionType, .selectorIdentifier: forSuperscript ? kSuperiorsSelector : kInferiorsSelector]
				#else
				let features: [FontDescriptor.FeatureKey: Any] = [.featureIdentifier: kVerticalPositionType, .typeIdentifier: forSuperscript ? kSuperiorsSelector : kInferiorsSelector]
				#endif
				return features
			}

			if styles.contains(.superscript) || styles.contains(.subscript) {
				let features = verticalPositionFeature(forSuperscript: styles.contains(.superscript))
				let descriptorAttributes: [FontDescriptor.AttributeName: Any] = [.featureSettings: [features]]
				descriptor = descriptor.addingAttributes(descriptorAttributes)
			}

			var attributes = [NSAttributedString.Key: Any]()

			attributes[.font] = Font(descriptor: descriptor, size: baseFont.pointSize)

			if styles.contains(.strikethrough) {
				attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
			}

			if styles.contains(.underline) {
				attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
			}

			result.addAttributes(attributes, range: range)
		}

		self.init(attributedString: result)
	}

}

/// This is a very, very basic implementation that only covers our needs.
private struct CountedSet<Element> where Element: Hashable {
	private var _storage = [Element: Int]()

	mutating func insert(_ element: Element) {
		_storage[element, default: 0] += 1
	}

	mutating func remove(_ element: Element) {
		guard var count = _storage[element] else { return }

		count -= 1

		if count == 0 {
			_storage.removeValue(forKey: element)
		} else {
			_storage[element] = count
		}
	}

	func contains(_ element: Element) -> Bool {
		return _storage[element] != nil
	}

	subscript(key: Element) -> Int {
		get {
			return _storage[key, default: 0]
		}
	}
}

private extension String {
	var decodedEntity: String {
		// It's possible the implementation will change, but for now it just calls this.
		(self as NSString).rsparser_stringByDecodingHTMLEntities() as String
	}
}
