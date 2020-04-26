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

	/// Adds a font and color to an attributed string.
	///
	/// - Parameters:
	///   - baseFont: The font to add.
	///   - color: The color to add.
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

			newSymbolicTraits.insert(symbolicTraits)

			var descriptor = baseDescriptor.addingAttributes(font.fontDescriptor.fontAttributes)

			#if canImport(AppKit)
			descriptor = descriptor.withSymbolicTraits(newSymbolicTraits)
			#else
			var descriptor = descriptor.withSymbolicTraits(newSymbolicTraits)!
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

		return mutable.copy() as! NSAttributedString
	}

	/// Creates an attributed string from HTML.

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

		init?(tag: String) {
			switch tag {
				case "b", "strong":
					self = .bold
				case "i", "em", "cite":
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

	private static func decode(entity: String) -> String {
		// TODO: Support all named entities

		guard entity.hasPrefix("&"), entity.hasSuffix(";") else { return entity }

		let name = entity.dropFirst().dropLast()

		if name.hasPrefix("#") {
			let value = name.dropFirst()
			var number: Int? = nil

			if value.hasPrefix("x") {
				number = Int(value.dropFirst(), radix: 16)
			} else {
				number = Int(value)
			}

			if let number = number, let c = UnicodeScalar(number) {
				return String(c)
			}
		} else {
			switch name {
				case "lt":
					return "<"
				case "gt":
					return ">"
				case "amp":
					return "&"
				case "quot":
					return "\""
				case "apos":
					return "'"
				default:
					break
			}
		}

		return entity
	}

	/// Returns an attributed string initialized from  HTML text containing basic inline stylistic tags.
	///
	/// - Parameters:
	///   - html: The HTML text.
	///   - font: The font to use. Defaults to the system font.
	///   - locale: The locale used for quotation marks when parsing `<q>` tags.
	convenience init(html: String, font: Font? = nil, locale: Locale = Locale.current) {
		let baseFont = font ?? Font.systemFont(ofSize: Font.systemFontSize)

		var inTag: InTag = .none
		var tagBuf = ""
		var tagStack = [String]()
		var currentStyles: Set<Style> = []

		var iterator = html.makeIterator()

		let result = NSMutableAttributedString()

		var attributeRanges = [(range: NSRange, styles: Set<Style>)]()

		while let char = iterator.next() {
			if char == "<" && inTag == .none {
				tagBuf.removeAll()

				guard let first = iterator.next() else { break }

				if first == "/" {
					inTag = .closing
				} else {
					inTag = .opening
					tagBuf.append(first)
				}
			} else if char == ">" && inTag != .none {
				if inTag == .opening {
					tagStack.append(tagBuf)

					if tagBuf == "q" {
						result.mutableString.append(locale.quotationBeginDelimiter ?? "\"")
					}

					let lastRange = attributeRanges.last?.range
					let location = lastRange != nil ? lastRange!.location + lastRange!.length : 0
					let range = NSRange(location: location, length: result.mutableString.length - location)

					let style = Style(tag: tagBuf)

					attributeRanges.append( (range: range, styles: currentStyles) )

					if style != nil {
						currentStyles.insert(style!)
					}


				} else {
					if tagBuf == "q" {
						result.mutableString.append(locale.quotationEndDelimiter ?? "\"")
					}

					let lastRange = attributeRanges.last?.range
					let location = lastRange != nil ? lastRange!.location + lastRange!.length : 0
					let range = NSRange(location: location, length: result.mutableString.length - location)

					attributeRanges.append( ( range: range, styles: currentStyles ))

					if let style = Style(tag: tagBuf) {
						currentStyles.remove(style)
					}

					let _ = tagStack.popLast() // TODO: Handle improperly-nested tags
				}

				inTag = .none
			} else if inTag != .none {
				tagBuf.append(char)
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


					result.mutableString.append(Self.decode(entity: entity))

					if let lastchar = lastchar { result.mutableString.append(String(lastchar)) }
				} else {
					result.mutableString.append(String(char))
				}
			}
		}

		result.addAttribute(.font, value: baseFont, range: NSRange(location: 0, length: result.length))

		for (range, styles) in attributeRanges {
			let currentFont = result.attribute(.font, at: range.location, effectiveRange: nil) as! Font
			let currentDescriptor = currentFont.fontDescriptor
			var descriptor = currentDescriptor.copy() as! FontDescriptor

			var attributes: [NSAttributedString.Key: Any] = [:]

			if styles.contains(.bold) {
				let traits: [FontDescriptor.TraitKey: Any] = [.weight: Font.Weight.bold]
				let descriptorAttributes: [FontDescriptor.AttributeName: Any] = [.traits: traits]
				descriptor = descriptor.addingAttributes(descriptorAttributes)
			}

			if styles.contains(.italic) {
				var symbolicTraits = currentDescriptor.symbolicTraits
				symbolicTraits.insert(.italic)
				descriptor = descriptor.withSymbolicTraits(symbolicTraits)
			}

			if styles.contains(.monospace) {
				var symbolicTraits = currentDescriptor.symbolicTraits
				symbolicTraits.insert(.monoSpace)
				descriptor = descriptor.withSymbolicTraits(symbolicTraits)
			}

			func verticalPositionFeature(forSuperscript: Bool) -> [FontDescriptor.FeatureKey: Any] {
				#if canImport(AppKit)
				let features: [FontDescriptor.FeatureKey: Any] = [.typeIdentifier: kVerticalPositionType, .selectorIdentifier: forSuperscript ? kSuperiorsSelector : kInferiorsSelector]
				#else
				let features: [FontDescriptor.FeatureKey: Any] = [.featureIdentifier: kVerticalPositionType, .typeIdentifier: forSuperscript ? kSuperiorsSelector : kInferiorsSelector]
				#endif
				return features
			}

			if styles.contains(.superscript) {
				let features = verticalPositionFeature(forSuperscript: true)
				let descriptorAttributes: [FontDescriptor.AttributeName: Any] = [.featureSettings: [features]]
				descriptor = descriptor.addingAttributes(descriptorAttributes)
			}

			if styles.contains(.subscript) {
				let features = verticalPositionFeature(forSuperscript: false)
				let descriptorAttributes: [FontDescriptor.AttributeName: Any] = [.featureSettings: [features]]
				descriptor = currentDescriptor.addingAttributes(descriptorAttributes)
			}

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
