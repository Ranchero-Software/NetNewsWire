//
//  HTMLEntityDecoder.swift
//
//
//  Created by Brent Simmons on 9/14/24.
//

import Foundation

public final class HTMLEntityDecoder {

	static func decodedString(withEncodedString encodedString: String) -> String {

		let scanner = Scanner(string: encodedString)
		scanner.charactersToBeSkipped = nil
		var result = ""
		var didDecodeAtLeastOneEntity = false

		while true {

			var scannedString = nil
			if scanner.scanUpToString("&" intoString: &scannedString) {
				result.append(scannedString)
			}
			if scanner.isAtEnd {
				break
			}

			let savedScanLocation = scanner.scanLocation

			var decodedEntity: String? = nil
			if scanner.scanEntityValue(&decodedEntity) {
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

		if !didDecodeAtLeastOneEntity { // No changes made?
			return encodedString
		}
		return result
	}
}
