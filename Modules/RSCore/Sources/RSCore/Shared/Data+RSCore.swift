//
//  Data+RSCore.swift
//  RSCore
//
//  Created by Nate Weaver on 2020-01-02.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif
import CommonCrypto

public extension Data {

	/// The MD5 hash of the data.
	var md5Hash: Data {

		#if canImport(CryptoKit)
		if #available(macOS 10.15, *) {
			let digest = Insecure.MD5.hash(data: self)
			return Data(digest)
		} else {
			return ccMD5Hash
		}
		#else
		return ccMD5Hash
		#endif

	}

	@available(macOS, deprecated: 10.15)
	@available(iOS, deprecated: 13.0)
	private var ccMD5Hash: Data {
		let len = Int(CC_MD5_DIGEST_LENGTH)
		let md = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: len)

		let _ = self.withUnsafeBytes {
			CC_MD5($0.baseAddress, numericCast($0.count), md)
		}

		return Data(bytes: md, count: len)
	}

	/// The MD5 has of the data, as a hexadecimal string.
	var md5String: String? {
		return md5Hash.hexadecimalString
	}

	/// Image signature constants.
	private enum ImageSignature {

		/// The signature for PNG data.
		///
		/// [PNG signature](http://www.w3.org/TR/PNG/#5PNG-file-signature)\:
		/// The first eight bytes of a PNG datastream always contain the following (decimal) values:
		///
		/// ```
		/// 137 80 78 71 13 10 26 10
		/// ```
		static let png = Data([137, 80, 78, 71, 13, 10, 26, 10])

		/// The signature for GIF 89a data.
		///
		/// [http://www.onicos.com/staff/iz/formats/gif.html](http://www.onicos.com/staff/iz/formats/gif.html)
		static let gif89a = "GIF89a".data(using: .ascii)!

		/// The signature for GIF 87a data.
		///
		/// [http://www.onicos.com/staff/iz/formats/gif.html](http://www.onicos.com/staff/iz/formats/gif.html)
		static let gif87a = "GIF87a".data(using: .ascii)!

		/// The signature for JPEG data.
		static let jpeg = Data([0xFF, 0xD8, 0xFF])

	}

	/// Check if data matches a signature at its start.
	///
	/// - Parameter signatures: An array of signatures to match against.
	/// - Returns: `true` if the data matches; `false` otherwise.
	private func matchesSignature(from signatures: [Data]) -> Bool {
		for signature in signatures {
			if self.prefix(signature.count) == signature {
				return true
			}
		}

		return false
	}

	/// Returns `true` if the data begins with the PNG signature.
	var isPNG: Bool {
		return matchesSignature(from: [ImageSignature.png])
	}

	/// Returns `true` if the data begins with a valid GIF signature.
	var isGIF: Bool {
		return matchesSignature(from: [ImageSignature.gif89a, ImageSignature.gif87a])
	}

	/// Returns `true` if the data begins with a valid JPEG signature.
	var isJPEG: Bool {
		return matchesSignature(from: [ImageSignature.jpeg])
	}

	/// Returns `true` if the data is an image (PNG, JPEG, or GIF).
	var isImage: Bool {
		return  isPNG || isJPEG || isGIF
	}

	/// Constants for `isProbablyHTML`.
	private enum RSSearch {

		static let lessThan = "<".utf8.first!
		static let greaterThan = ">".utf8.first!

		/// Tags in UTF-8/ASCII format.
		enum UTF8 {
			static let lowercaseHTML = "html".data(using: .utf8)!
			static let lowercaseBody = "body".data(using: .utf8)!
			static let uppercaseHTML = "HTML".data(using: .utf8)!
			static let uppercaseBody = "BODY".data(using: .utf8)!
			static let lowercaseHead = "head".data(using: .utf8)!
			static let uppercaseHead = "HEAD".data(using: .utf8)!
			static let lowercaseDoctype = "<!doctype".data(using: .utf8)!
			static let uppercaseDoctype = "<!DOCTYPE".data(using: .utf8)!
			static let lowercaseDiv = "div".data(using: .utf8)!
			static let uppercaseDiv = "DIV".data(using: .utf8)!
			static let lowercaseP = "p".data(using: .utf8)!
			static let uppercaseP = "P".data(using: .utf8)!
			static let lowercaseSpan = "span".data(using: .utf8)!
			static let uppercaseSpan = "SPAN".data(using: .utf8)!
		}

		/// Tags in UTF-16 format.
		enum UTF16 {
			static let lowercaseHTML = "html".data(using: .utf16LittleEndian)!
			static let lowercaseBody = "body".data(using: .utf16LittleEndian)!
			static let uppercaseHTML = "HTML".data(using: .utf16LittleEndian)!
			static let uppercaseBody = "BODY".data(using: .utf16LittleEndian)!
			static let lowercaseHead = "head".data(using: .utf16LittleEndian)!
			static let uppercaseHead = "HEAD".data(using: .utf16LittleEndian)!
			static let lowercaseDoctype = "<!doctype".data(using: .utf16LittleEndian)!
			static let uppercaseDoctype = "<!DOCTYPE".data(using: .utf16LittleEndian)!
			static let lowercaseDiv = "div".data(using: .utf16LittleEndian)!
			static let uppercaseDiv = "DIV".data(using: .utf16LittleEndian)!
			static let lowercaseP = "p".data(using: .utf16LittleEndian)!
			static let uppercaseP = "P".data(using: .utf16LittleEndian)!
			static let lowercaseSpan = "span".data(using: .utf16LittleEndian)!
			static let uppercaseSpan = "SPAN".data(using: .utf16LittleEndian)!
		}

	}

	/// Returns `true` if the data looks like it could be HTML.
	///
	/// Advantage is taken of the fact that most common encodings are ASCII-compatible, aside from UTF-16,
	/// which for ASCII codepoints is essentially ASCII characters with nulls in between.
	///
	/// An uncommon exception is any EBCDIC-derived encoding.
	///
	/// This method uses detection algorithm that doesn't require both html and body tags.
	/// It looks for DOCTYPE declarations, html tags, and common HTML structural elements.
	var isProbablyHTML: Bool {

		if !self.contains(RSSearch.lessThan) || !self.contains(RSSearch.greaterThan) {
			return false
		}

		// Check for DOCTYPE declaration (strong indicator)
		if self.range(of: RSSearch.UTF8.lowercaseDoctype) != nil || self.range(of: RSSearch.UTF8.uppercaseDoctype) != nil {
			return true
		}

		if self.range(of: RSSearch.UTF16.lowercaseDoctype) != nil || self.range(of: RSSearch.UTF16.uppercaseDoctype) != nil {
			return true
		}

		// Check for html tag (strong indicator)
		if self.range(of: RSSearch.UTF8.lowercaseHTML) != nil || self.range(of: RSSearch.UTF8.uppercaseHTML) != nil {
			return true
		}

		if self.range(of: RSSearch.UTF16.lowercaseHTML) != nil || self.range(of: RSSearch.UTF16.uppercaseHTML) != nil {
			return true
		}

		// Check for head tag (strong indicator)
		if self.range(of: RSSearch.UTF8.lowercaseHead) != nil || self.range(of: RSSearch.UTF8.uppercaseHead) != nil {
			return true
		}

		if self.range(of: RSSearch.UTF16.lowercaseHead) != nil || self.range(of: RSSearch.UTF16.uppercaseHead) != nil {
			return true
		}

		// Check for body tag (good indicator)
		if self.range(of: RSSearch.UTF8.lowercaseBody) != nil || self.range(of: RSSearch.UTF8.uppercaseBody) != nil {
			return true
		}

		if self.range(of: RSSearch.UTF16.lowercaseBody) != nil || self.range(of: RSSearch.UTF16.uppercaseBody) != nil {
			return true
		}

		// Check for common HTML structural elements (weaker but still useful indicators)
		let hasCommonHTMLElements = {
			// Check for div tags
			if self.range(of: RSSearch.UTF8.lowercaseDiv) != nil || self.range(of: RSSearch.UTF8.uppercaseDiv) != nil ||
			   self.range(of: RSSearch.UTF16.lowercaseDiv) != nil || self.range(of: RSSearch.UTF16.uppercaseDiv) != nil {
				return true
			}

			// Check for p tags
			if self.range(of: RSSearch.UTF8.lowercaseP) != nil || self.range(of: RSSearch.UTF8.uppercaseP) != nil ||
			   self.range(of: RSSearch.UTF16.lowercaseP) != nil || self.range(of: RSSearch.UTF16.uppercaseP) != nil {
				return true
			}

			// Check for span tags
			if self.range(of: RSSearch.UTF8.lowercaseSpan) != nil || self.range(of: RSSearch.UTF8.uppercaseSpan) != nil ||
			   self.range(of: RSSearch.UTF16.lowercaseSpan) != nil || self.range(of: RSSearch.UTF16.uppercaseSpan) != nil {
				return true
			}

			return false
		}()

		return hasCommonHTMLElements
	}

	/// A representation of the data as a hexadecimal string.
	///
	/// Returns `nil` if the data is empty.
	var hexadecimalString: String? {

		if count == 0 {
			return nil
		}

		// Special case for MD5
		if count == 16 {
			return String(format: "%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", self[0], self[1], self[2], self[3], self[4], self[5], self[6], self[7], self[8], self[9], self[10], self[11], self[12], self[13], self[14], self[15])
		}

		return reduce("") { $0 + String(format: "%02x", $1) }

	}

}
