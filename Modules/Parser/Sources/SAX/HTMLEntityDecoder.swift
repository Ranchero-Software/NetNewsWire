//
//  HTMLEntityDecoder.swift
//
//
//  Created by Brent Simmons on 9/14/24.
//

import Foundation

public final class HTMLEntityDecoder {

	static func decodedString(withEncodedString encodedString: String) -> String {

		let scanner = EntityScanner(string: encodedString)
		var result = ""
		var didDecodeAtLeastOneEntity = false

		while true {

			let scannedString = scanner.scanUpTo(Character("&"))
			if !scannedString.isEmpty {
				result.append(scannedString)
			}
			if scanner.isAtEnd {
				break
			}

			let savedScanLocation = scanner.scanLocation

			if let decodedEntity = scanner.scanEntityValue() {
				result.append(decodedEntity)
				didDecodeAtLeastOneEntity = true
			}
			else {
				result.append("&")
				scanner.scanLocation = savedScanLocation + 1
			}

			if scanner.isAtEnd {
				break
			}
		}

		if !didDecodeAtLeastOneEntity { // No entities decoded?
			return encodedString
		}
		return result
	}
}

/// Purpose-built version of NSScanner, which has deprecated the parts we want to use.
final class EntityScanner {

	let string: String
	let count: Int
	var scanLocation = 0

	var isAtEnd: Bool {
		scanLocation >= count
	}

	var currentCharacter: Character? {
		guard !isAtEnd, let index = string.index(string.startIndex, offsetBy: scanLocation, limitedBy: string.endIndex) else {
			return nil
		}
		return string[index]
	}

	init(string: String) {
		self.string = string
		self.count = string.count
	}

	/// Scans up to `characterToFind` and returns the characters up to (and not including) `characterToFind`.
	/// - Returns: the scanned portion before `characterToFind`. May be empty string.
	func scanUpTo(_ characterToFind: Character) -> String {

		var scanned = ""

		while true {

			guard let ch = currentCharacter else {
				break
			}
			scanLocation += 1

			if ch == characterToFind {
				break
			}
			else {
				scanned.append(ch)
			}
		}

		return scanned
	}

//	- (BOOL)rs_scanEntityValue:(NSString * _Nullable * _Nullable)decodedEntity {
//
//		NSString *s = self.string;
//		NSUInteger initialScanLocation = self.scanLocation;
//		static NSUInteger maxEntityLength = 20; // It’s probably smaller, but this is just for sanity.
//
//		while (true) {
//
//			unichar ch = [s characterAtIndex:self.scanLocation];
//			if ([NSCharacterSet.whitespaceAndNewlineCharacterSet characterIsMember:ch]) {
//				break;
//			}
//			if (ch == ';') {
//				if (!decodedEntity) {
//					return YES;
//				}
//				NSString *rawEntity = [s substringWithRange:NSMakeRange(initialScanLocation + 1, (self.scanLocation - initialScanLocation) - 1)];
//				*decodedEntity = [rawEntity rs_stringByDecodingEntity];
//				self.scanLocation = self.scanLocation + 1;
//				return *decodedEntity != nil;
//			}
//
//			self.scanLocation = self.scanLocation + 1;
//			if (self.scanLocation - initialScanLocation > maxEntityLength) {
//				break;
//			}
//			if (self.isAtEnd) {
//				break;
//			}
//		}
//
//		return NO;
//	}

	func scanEntityValue() -> String? {

		let initialScanLocation = scanLocation
		let maxEntityLength = 20 // It’s probably smaller, but this is just for sanity.

		while true {

			guard let ch = currentCharacter

		}

		return nil
	}
}
