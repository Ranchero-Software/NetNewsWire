//
//  StripHTML.swift
//  RSCore
//
//  Created by Brent Simmons on 4/20/26.
//  Copyright © 2026 Brent Simmons. All rights reserved.
//

// Swift port of the previous `striphtml.c`. Operates on the string's
// underlying UTF-8 storage and writes directly into a new `String`'s
// uninitialized storage.
//
// Benchmarks (Apple silicon M1, release build, best-of-10
// from XCTest measure blocks — see `StripHTMLTests.swift`):
//
//     Benchmark                        C (before)   Swift (after)   Speedup
//     ------------------------------   ----------   -------------   -------
//     Synthetic, 1000 iterations          0.00271         0.00124     2.19x
//     Real-world, 100 iterations          0.01783         0.01190     1.50x
//       (apple.html + daringfireball.html
//        + inessential.html + scripting.html,
//        ~437 KB total per pass; times in seconds)

// MARK: - Public entry point

public extension String {

	/// Strips HTML from a string.
	///
	/// - Parameter maxCharacters: The maximum characters in the return string.
	/// If `nil`, the whole string is used.
	///
	/// This function removes HTML tags and script/style content, collapses
	/// whitespace, and trims leading/trailing whitespace. Works on plain text
	/// as well to trim and collapse whitespace.
	///
	/// History: the original implementation, written in Swift, took up about
	/// 10% of the work during scrolling the timeline, and was the single
	/// biggest chunk of work during scrolling. (According to the Instruments
	/// Time Profiler.) A subsequent C port dropped that to about 2%; this
	/// pure-Swift rewrite (issue #5270) matches or beats the C version —
	/// see the benchmark table at the top of this file.
	func strippingHTML(maxCharacters: Int? = nil) -> String {
		if self.isEmpty {
			return ""
		}
		var source = self
		let maxChars = maxCharacters ?? 0
		return source.withUTF8 { inBytes -> String in
			let capacity = inBytes.count
			if capacity == 0 {
				return ""
			}
			return String(unsafeUninitializedCapacity: capacity) { outBytes in
				StripHTML.process(input: inBytes, output: outBytes, maxCharacters: maxChars)
			}
		}
	}
}

// MARK: - Implementation

private enum StripHTML {

	// MARK: Tags

	// Tags are `StaticString`, not the inferred `String`, for two reasons:
	// (1) `tag.utf8Start` gives `matches(…)` a direct `UnsafePointer<UInt8>`
	// into the binary's UTF-8 bytes — no closure, no bridging, no ARC;
	// (2) `tag.utf8CodeUnitCount` is a stored field set by the compiler at
	// literal creation, so `someTag.utf8CodeUnitCount` at each call site
	// folds to a constant — no need for a separate `…TagLength` let.
	//
	// `matches(…)` requires ASCII-lowercase tag bytes; that's a convention
	// enforced by this comment and the declarations immediately below, not
	// by the type system.

	// Script/style tags whose bodies are discarded entirely.
	private static let scriptTag: StaticString = "script"
	private static let styleTag: StaticString = "style"
	private static let closeScriptTag: StaticString = "/script"
	private static let closeStyleTag: StaticString = "/style"

	// Block-level tags — each injects a single space so word boundaries
	// survive when the surrounding markup is removed.
	private static let pTag: StaticString = "p>"
	private static let closePTag: StaticString = "/p>"
	private static let divTag: StaticString = "div>"
	private static let closeDivTag: StaticString = "/div>"
	private static let blockquoteTag: StaticString = "blockquote>"
	private static let closeBlockquoteTag: StaticString = "/blockquote>"
	private static let brTag: StaticString = "br>"
	private static let brSlashTag: StaticString = "br/>"
	private static let brSpaceSlashTag: StaticString = "br />"
	private static let closeLiTag: StaticString = "/li>"

	// MARK: Byte-level helpers

	/// Lowercase an ASCII letter. Non-letters are returned unchanged.
	@inline(__always)
	private static func asciiToLower(_ byte: UInt8) -> UInt8 {
		// Uppercase `A`...`Z` differ from lowercase `a`...`z` only in the
		// 0x20 bit, so setting that bit is cheaper than a table lookup or
		// `tolower`.
		if byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "Z") {
			return byte | 0x20
		}
		return byte
	}

	/// Number of bytes in the UTF-8 character whose first byte is `leadByte`.
	/// Invalid lead bytes are treated as one-byte characters.
	@inline(__always)
	private static func utf8CharacterByteCount(_ leadByte: UInt8) -> Int {
		if (leadByte & 0x80) == 0 { return 1 }    // 0xxxxxxx — ASCII
		if (leadByte & 0xE0) == 0xC0 { return 2 } // 110xxxxx — 2-byte lead
		if (leadByte & 0xF0) == 0xE0 { return 3 } // 1110xxxx — 3-byte lead
		if (leadByte & 0xF8) == 0xF0 { return 4 } // 11110xxx — 4-byte lead
		return 1                                   // Invalid — treat as single byte
	}

	/// Case-insensitively test whether the bytes at `base + position` start
	/// with `tag`. `tag` must be ASCII-lowercase — input bytes are lowered
	/// before comparison. Callers must ensure the read is in-bounds before
	/// calling; the bounds check stays at the call site because short-circuit
	/// evaluation there benchmarks ~28% faster on real-world input than
	/// pushing the check inside this function. (The cold bounds-fail path is
	/// optimized better by the compiler when it lives outside a tight
	/// `@inline(__always)` helper.)
	@inline(__always)
	private static func matches(_ base: UnsafePointer<UInt8>, at position: Int, _ tag: StaticString) -> Bool {
		let tagCount = tag.utf8CodeUnitCount
		let tagPointer = tag.utf8Start
		var offset = 0
		while offset < tagCount {
			if asciiToLower(base[position + offset]) != tagPointer[offset] {
				return false
			}
			offset += 1
		}
		return true
	}

	// MARK: Main entry (called from `String.strippingHTML`)

	/// Strip HTML tags from a UTF-8 byte buffer, writing the plain-text
	/// result into `output`. Produces byte-for-byte the same output as the
	/// previous `striphtml.c`, so the expected-output fixtures in
	/// `StripHTMLTests.swift` stay valid.
	///
	/// Behavior:
	/// - Tags (`<…>`) are removed; their inner markup is discarded.
	/// - `<script>…</script>` and `<style>…</style>` bodies are discarded
	///   entirely.
	/// - Common block-level tags (`<p>`, `</p>`, `<div>`, `</div>`,
	///   `<blockquote>`, `</blockquote>`, `<br>`, `<br/>`, `<br />`, `</li>`)
	///   inject a space so word boundaries aren't lost when the surrounding
	///   tags are removed.
	/// - Runs of whitespace (space, tab, CR, LF) collapse to a single space.
	/// - Leading and trailing spaces are trimmed.
	/// - HTML entities (`&amp;` etc.) are **not** decoded.
	///
	/// State-machine roles:
	/// - `tagLevel`: depth of `<`/`>` nesting. Incremented on `<`, decremented
	///   on the matching `>` — but see `inScript`/`inStyle` for the exception.
	/// - `inScript` / `inStyle`: true between `<script>` and `</script>` (or
	///   the style pair). While either is true, a `<` does **not** bump
	///   `tagLevel`, so the `>` at the end of the closing tag is what brings
	///   `tagLevel` back to zero. That's the one subtle bit of the algorithm.
	/// - `lastCharacterWasSpace`: prevents doubled spaces. Starts `true` so
	///   leading whitespace is skipped without a separate branch.
	/// - `charactersAdded`: counts output characters for the `maxCharacters`
	///   cap.
	///
	/// - Returns: the number of bytes written to `output`.
	static func process(input: UnsafeBufferPointer<UInt8>, output: UnsafeMutableBufferPointer<UInt8>, maxCharacters: Int) -> Int {

		let inputCount = input.count
		let outputCapacity = output.count

		guard inputCount > 0, outputCapacity > 0,
		      let inputBase = input.baseAddress,
		      let outputBase = output.baseAddress else {
			return 0
		}

		var inputIndex = 0
		var outputIndex = 0
		var tagLevel = 0
		var inScript = false
		var inStyle = false
		var lastCharacterWasSpace = true
		var charactersAdded = 0

		while inputIndex < inputCount && outputIndex < outputCapacity {

			if maxCharacters > 0 && charactersAdded >= maxCharacters {
				break
			}

			let byte = inputBase[inputIndex]

			if byte == UInt8(ascii: "<") {

				if !inScript && !inStyle {
					tagLevel += 1
				}

				// Script / style detection.
				if inputIndex + scriptTag.utf8CodeUnitCount < inputCount && matches(inputBase, at: inputIndex + 1, scriptTag) {
					inScript = true
				} else if inputIndex + styleTag.utf8CodeUnitCount < inputCount && matches(inputBase, at: inputIndex + 1, styleTag) {
					inStyle = true
				} else if inputIndex + closeScriptTag.utf8CodeUnitCount < inputCount && matches(inputBase, at: inputIndex + 1, closeScriptTag) {
					inScript = false
				} else if inputIndex + closeStyleTag.utf8CodeUnitCount < inputCount && matches(inputBase, at: inputIndex + 1, closeStyleTag) {
					inStyle = false
				}

				// Block-level tags — inject a space so word boundaries survive.
				let isBlockTag =
					(inputIndex + pTag.utf8CodeUnitCount < inputCount && matches(inputBase, at: inputIndex + 1, pTag)) ||
					(inputIndex + closePTag.utf8CodeUnitCount < inputCount && matches(inputBase, at: inputIndex + 1, closePTag)) ||
					(inputIndex + divTag.utf8CodeUnitCount < inputCount && matches(inputBase, at: inputIndex + 1, divTag)) ||
					(inputIndex + closeDivTag.utf8CodeUnitCount < inputCount && matches(inputBase, at: inputIndex + 1, closeDivTag)) ||
					(inputIndex + blockquoteTag.utf8CodeUnitCount < inputCount && matches(inputBase, at: inputIndex + 1, blockquoteTag)) ||
					(inputIndex + closeBlockquoteTag.utf8CodeUnitCount < inputCount && matches(inputBase, at: inputIndex + 1, closeBlockquoteTag)) ||
					(inputIndex + brTag.utf8CodeUnitCount < inputCount && matches(inputBase, at: inputIndex + 1, brTag)) ||
					(inputIndex + brSlashTag.utf8CodeUnitCount < inputCount && matches(inputBase, at: inputIndex + 1, brSlashTag)) ||
					(inputIndex + brSpaceSlashTag.utf8CodeUnitCount < inputCount && matches(inputBase, at: inputIndex + 1, brSpaceSlashTag)) ||
					(inputIndex + closeLiTag.utf8CodeUnitCount < inputCount && matches(inputBase, at: inputIndex + 1, closeLiTag))

				if isBlockTag && !lastCharacterWasSpace && outputIndex < outputCapacity {
					outputBase[outputIndex] = UInt8(ascii: " ")
					outputIndex += 1
					lastCharacterWasSpace = true
					charactersAdded += 1
				}

				inputIndex += 1
				continue
			}

			if byte == UInt8(ascii: ">") {
				if !inScript && !inStyle && tagLevel > 0 {
					tagLevel -= 1
				}
				inputIndex += 1
				continue
			}

			if tagLevel > 0 || inScript || inStyle {
				inputIndex += 1
				continue
			}

			// Collapse runs of whitespace (space, tab, CR, LF) to a single space.
			if byte == UInt8(ascii: " ") || byte == UInt8(ascii: "\t") || byte == UInt8(ascii: "\r") || byte == UInt8(ascii: "\n") {
				if !lastCharacterWasSpace {
					outputBase[outputIndex] = UInt8(ascii: " ")
					outputIndex += 1
					lastCharacterWasSpace = true
					charactersAdded += 1
				}
				inputIndex += 1
				continue
			}

			// It’s a content character — copy to output, update state.
			lastCharacterWasSpace = false

			// ASCII fast path (overwhelming majority of bytes in real HTML).
			if byte < 0x80 {
				outputBase[outputIndex] = byte
				outputIndex += 1
				inputIndex += 1
				charactersAdded += 1
				continue
			}

			// Multi-byte UTF-8.
			let byteCount = utf8CharacterByteCount(byte)
			if outputIndex + byteCount <= outputCapacity && inputIndex + byteCount <= inputCount {
				var offset = 0
				while offset < byteCount {
					outputBase[outputIndex + offset] = inputBase[inputIndex + offset]
					offset += 1
				}
				outputIndex += byteCount
				inputIndex += byteCount
				charactersAdded += 1
			} else {
				break
			}
		}

		// Trim trailing spaces.
		while outputIndex > 0 && outputBase[outputIndex - 1] == UInt8(ascii: " ") {
			outputIndex -= 1
		}

		return outputIndex
	}
}
