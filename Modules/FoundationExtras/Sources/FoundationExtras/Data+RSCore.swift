//
//  Data+RSCore.swift
//  RSCore
//
//  Created by Nate Weaver on 2020-01-02.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import CryptoKit

public extension Data {

	/// The MD5 hash of the data.
	var md5Hash: Data {

		let digest = Insecure.MD5.hash(data: self)
		return Data(digest)
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
		}

		/// Tags in UTF-16 format.
		enum UTF16 {
			static let lowercaseHTML = "html".data(using: .utf16LittleEndian)!
			static let lowercaseBody = "body".data(using: .utf16LittleEndian)!
			static let uppercaseHTML = "HTML".data(using: .utf16LittleEndian)!
			static let uppercaseBody = "BODY".data(using: .utf16LittleEndian)!
		}

	}

	/// Returns `true` if the data looks like it could be HTML.
	///
	/// Advantage is taken of the fact that most common encodings are ASCII-compatible, aside from UTF-16,
	/// which for ASCII codepoints is essentially ASCII characters with nulls in between.
	///
	/// An uncommon exception is any EBCDIC-derived encoding.
	var isProbablyHTML: Bool {

		if !self.contains(RSSearch.lessThan) || !self.contains(RSSearch.greaterThan) {
			return false
		}

		if (self.range(of: RSSearch.UTF8.lowercaseHTML) != nil || self.range(of: RSSearch.UTF8.uppercaseHTML) != nil)
			&& (self.range(of: RSSearch.UTF8.lowercaseBody) != nil || self.range(of: RSSearch.UTF8.uppercaseBody) != nil) {
			return true
		}

		if (self.range(of: RSSearch.UTF16.lowercaseHTML) != nil || self.range(of: RSSearch.UTF16.uppercaseHTML) != nil)
			&& (self.range(of: RSSearch.UTF16.lowercaseBody) != nil || self.range(of: RSSearch.UTF16.uppercaseBody) != nil) {
			return true
		}

		return false
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
