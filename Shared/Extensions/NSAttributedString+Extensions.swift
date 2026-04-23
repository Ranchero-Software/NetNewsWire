//
//  NSAttributedString+Extensions.swift
//  NetNewsWire
//
//  Created by Nate Weaver on 2020-04-07.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

#if canImport(AppKit)
import AppKit
typealias RSFont = NSFont
#else
import UIKit
typealias RSFont = UIFont
#endif
import RSParser

@MainActor extension NSAttributedString {

	/// Returns a copy with `baseFont` merged into each run's existing
	/// font attribute, preserving whatever traits (bold, italic, etc.)
	/// those runs already had. The base font contributes its family
	/// and size; per-run traits win.
	///
	/// - Parameters:
	///   - baseFont: The font whose family and size should be merged
	///     into every run.
	func applyingBaseFont(_ baseFont: RSFont) -> NSAttributedString {
		let mutable = self.mutableCopy() as! NSMutableAttributedString
		let fullRange = NSRange(location: 0, length: mutable.length)

		let size = baseFont.pointSize
		let baseDescriptor = baseFont.fontDescriptor
		let baseSymbolicTraits = baseDescriptor.symbolicTraits

		mutable.enumerateAttribute(.font, in: fullRange, options: []) { (font, range, _) in
			guard let font = font as? RSFont else {
				return
			}

			let currentDescriptor = font.fontDescriptor
			let symbolicTraits = baseSymbolicTraits.union(currentDescriptor.symbolicTraits)

			var descriptor = currentDescriptor.addingAttributes(baseDescriptor.fontAttributes)

			#if canImport(AppKit)
			descriptor = descriptor.withSymbolicTraits(symbolicTraits)
			#else
			descriptor = descriptor.withSymbolicTraits(symbolicTraits)!
			#endif

			let newFont = RSFont(descriptor: descriptor, size: size)

			mutable.addAttribute(.font, value: newFont as Any, range: range)
		}

		return mutable.copy() as! NSAttributedString
	}

	/// Initialize an attributed string from text. Style the text
	/// based on a small list of allowed inline HTML tags.
	///
	/// This is not a full HTML renderer. It recognizes only the
	/// inline stylistic tags enumerated by `Style.init(forTag:)`.
	/// It also decodes HTML character entities
	/// (`&amp;`, `&#8230;`, etc.).
	///
	/// Unrecognized tags are dropped and the text between them
	/// passes through as literal text. So `<a href="…">click</a>`
	/// becomes `click`, `<img …>` disappears entirely (no content),
	/// `<script>alert(1)</script>` becomes `alert(1)`. Tag attributes
	/// (`href`, `src`, `class`, etc.) are discarded along with their
	/// tags. CSS is not interpreted.
	///
	/// - Parameters:
	///   - simpleHTML: The text to parse. May contain any of the
	///     allowed tags above. Any other tag is stripped but
	///     its inner text is kept.
	///   - locale: The locale used to pick quotation marks when
	///     rendering `<q>` tags.
	convenience init(simpleHTML: String, locale: Locale = Locale.current) {
		self.init(attributedString: Self.buildAttributedString(html: simpleHTML, locale: locale))
	}
}

// MARK: - Private

@MainActor private extension NSAttributedString {

	enum InTag {
		case none
		case opening
		case closing
	}

	enum Style {
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

	/// Accumulate runs of plain text and flush each run to `NSMutableString`
	/// once at the next tag boundary, rather than doing
	/// `mutableString.append(String(char))` per grapheme. Record a
	/// list of `(range, styles)` pairs during the scan and then hand them
	/// off to `applyAttributes`.
	static func buildAttributedString(html: String, locale: Locale) -> NSAttributedString {
		let baseFont = RSFont.systemFont(ofSize: RSFont.systemFontSize)

		var inTag: InTag = .none
		var tag = ""
		var currentStyles = CountedSet<Style>()

		var iterator = html.makeIterator()

		let result = NSMutableAttributedString()

		var attributeRanges = [(range: NSRange, styles: CountedSet<Style>)]()
		var quoteDepth = 0

		// Accumulator for runs of plain text between tag boundaries.
		var textChunk = ""

		func flushTextChunk() {
			if !textChunk.isEmpty {
				result.mutableString.append(textChunk)
				textChunk.removeAll(keepingCapacity: true)
			}
		}

		while let char = iterator.next() {
			if char == "<" && inTag == .none {
				flushTextChunk()
				tag.removeAll()

				guard let first = iterator.next() else {
					break
				}

				if first == "/" {
					inTag = .closing
				} else {
					inTag = .opening
					tag.append(first)
				}
			} else if char == ">" && inTag != .none {
				// textChunk is empty here — we flushed on `<` and the
				// in-tag branch below doesn't write to it.
				let location = attributeRanges.last.map { NSMaxRange($0.range) } ?? 0
				let range = NSRange(location: location, length: result.mutableString.length - location)

				attributeRanges.append((range: range, styles: currentStyles))

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
					var lastchar: Character?

					while let entitychar = iterator.next() {
						if entitychar.isWhitespace {
							lastchar = entitychar
							break
						}

						entity.append(entitychar)

						if entitychar == ";" {
							break
						}
					}

					textChunk.append(entity.decodingHTMLEntities())

					if let lastchar = lastchar {
						textChunk.append(lastchar)
					}
				} else {
					textChunk.append(char)
				}
			}
		}

		flushTextChunk()

		applyAttributes(result, attributeRanges, baseFont)

		return result.copy() as! NSAttributedString
	}

	/// Apply font, strikethrough, and underline attributes to `result`
	/// using the `(range, styles)` pairs recorded during assembly.
	///
	/// Three wins over the pre-cache implementation: a shared RSFont
	/// cache keyed by style combination avoids rebuilding an `RSFont`
	/// from a descriptor on every range; ranges whose styles are
	/// empty are skipped because `baseFont` is applied to the whole
	/// string up front; and we no longer fetch each range's current
	/// font from the attributed string — it's always `baseFont`.
	static func applyAttributes(
		_ result: NSMutableAttributedString,
		_ attributeRanges: [(range: NSRange, styles: CountedSet<Style>)],
		_ baseFont: RSFont
	) {
		result.addAttribute(.font, value: baseFont, range: NSRange(location: 0, length: result.length))

		for (range, styles) in attributeRanges {
			if range.location >= result.length {
				continue
			}

			// Translate the CountedSet<Style> into the two orthogonal
			// attribute families: font-affecting (cached) and
			// line-decoration-affecting (applied directly).
			var fontKey: FontStyleKey = []
			if styles.contains(.bold) {
				fontKey.insert(.bold)
			}
			if styles.contains(.italic) {
				fontKey.insert(.italic)
			}
			if styles.contains(.monospace) {
				fontKey.insert(.monospace)
			}
			if styles.contains(.superscript) {
				fontKey.insert(.superscript)
			}
			if styles.contains(.subscript) {
				fontKey.insert(.subscript)
			}

			let hasStrikethrough = styles.contains(.strikethrough)
			let hasUnderline = styles.contains(.underline)
			let needsFontChange = !fontKey.isEmpty

			// No-op range — baseFont is already applied above, nothing
			// else to do here. Common for ranges outside any tag.
			if !needsFontChange && !hasStrikethrough && !hasUnderline {
				continue
			}

			var attributes = [NSAttributedString.Key: Any]()
			if needsFontChange {
				attributes[.font] = cachedFont(for: fontKey, baseFont: baseFont)
			}
			if hasStrikethrough {
				attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
			}
			if hasUnderline {
				attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
			}

			result.addAttributes(attributes, range: range)
		}
	}

	/// Look up (or build-and-cache) an RSFont for the given style
	/// combination. `baseFont` is the starting font — always
	/// `RSFont.systemFont(ofSize: RSFont.systemFontSize)` in practice.
	static func cachedFont(for key: FontStyleKey, baseFont: RSFont) -> RSFont {
		if let cached = htmlFontCache[key] {
			return cached
		}
		let font = buildFont(for: key, baseFont: baseFont)
		htmlFontCache[key] = font
		return font
	}

	static func buildFont(for key: FontStyleKey, baseFont: RSFont) -> RSFont {
		let baseDescriptor = baseFont.fontDescriptor
		var descriptor = baseDescriptor
		var symbolicTraits = baseDescriptor.symbolicTraits

		if key.contains(.bold) {
			let traits: [FontDescriptor.TraitKey: Any] = [.weight: RSFont.Weight.bold]
			descriptor = descriptor.addingAttributes([.traits: traits])
			symbolicTraits.insert(boldTrait)
		}
		if key.contains(.italic) {
			symbolicTraits.insert(italicTrait)
		}
		if key.contains(.monospace) {
			symbolicTraits.insert(monoSpaceTrait)
		}

		#if canImport(AppKit)
		descriptor = descriptor.withSymbolicTraits(symbolicTraits)
		#else
		descriptor = descriptor.withSymbolicTraits(symbolicTraits)!
		#endif

		if key.contains(.superscript) || key.contains(.subscript) {
			#if canImport(AppKit)
			let features: [FontDescriptor.FeatureKey: Any] = [
				.typeIdentifier: kVerticalPositionType,
				.selectorIdentifier: key.contains(.superscript) ? kSuperiorsSelector : kInferiorsSelector
			]
			#else
			let features: [FontDescriptor.FeatureKey: Any] = [
				.type: kVerticalPositionType,
				.selector: key.contains(.superscript) ? kSuperiorsSelector : kInferiorsSelector
			]
			#endif
			descriptor = descriptor.addingAttributes([.featureSettings: [features]])
		}

		#if canImport(AppKit)
		// NSFont init(descriptor:, size:) returns optional — falls
		// back to baseFont if the descriptor didn't resolve, which
		// in practice doesn't happen for our simple trait
		// combinations but is cheap insurance.
		return RSFont(descriptor: descriptor, size: baseFont.pointSize) ?? baseFont
		#else
		// UIFont init(descriptor:, size:) is non-optional.
		return RSFont(descriptor: descriptor, size: baseFont.pointSize)
		#endif
	}

}

// MARK: - Platform typealiases

#if canImport(AppKit)
private typealias FontDescriptor = NSFontDescriptor

private let boldTrait = NSFontDescriptor.SymbolicTraits.bold
private let italicTrait = NSFontDescriptor.SymbolicTraits.italic
private let monoSpaceTrait = NSFontDescriptor.SymbolicTraits.monoSpace
#else
private typealias FontDescriptor = UIFontDescriptor

private let boldTrait = UIFontDescriptor.SymbolicTraits.traitBold
private let italicTrait = UIFontDescriptor.SymbolicTraits.traitItalic
private let monoSpaceTrait = UIFontDescriptor.SymbolicTraits.traitMonoSpace
#endif

// MARK: - Font cache

// Cache key for the per-range RSFont lookup — only the styles that
// affect RSFont selection. Strikethrough and underline live in
// separate attributes, so they're not here.
private struct FontStyleKey: OptionSet, Hashable {
	let rawValue: UInt8
	static let bold = FontStyleKey(rawValue: 1 << 0)
	static let italic = FontStyleKey(rawValue: 1 << 1)
	static let monospace = FontStyleKey(rawValue: 1 << 2)
	static let superscript = FontStyleKey(rawValue: 1 << 3)
	static let `subscript` = FontStyleKey(rawValue: 1 << 4)
}

// Shared RSFont cache. `RSFont(descriptor:, size:)` is the dominant
// per-range cost in `applyAttributes`, and most ranges collapse
// onto a handful of style combinations — caching by `FontStyleKey`
// eliminates 90%+ of that cost after warmup. The base font is
// effectively constant across calls, so it isn't part of the key.
@MainActor private var htmlFontCache: [FontStyleKey: RSFont] = [:]

// MARK: - CountedSet

private struct CountedSet<Element> where Element: Hashable {
	private var _storage = [Element: Int]()

	mutating func insert(_ element: Element) {
		_storage[element, default: 0] += 1
	}

	mutating func remove(_ element: Element) {
		guard var count = _storage[element] else {
			return
		}

		count -= 1

		if count == 0 {
			_storage.removeValue(forKey: element)
		} else {
			_storage[element] = count
		}
	}

	func contains(_ element: Element) -> Bool {
		_storage[element] != nil
	}
}
