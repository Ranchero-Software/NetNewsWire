//
//  Data+Parser.swift
//
//
//  Created by Brent Simmons on 8/24/24.
//

import Foundation

public extension Data {

	/// Return true if the data contains a given String.
	///
	/// Assumes that the data is UTF-8 or similar encoding —
	/// if it’s UTF-16 or UTF-32, for instance, this will always return false.
	/// Luckily these are rare.
	///
	/// The String to search for should be something that could be encoded
	/// in ASCII — like "<opml" or "<rss". (In other words,
	/// the sequence of characters would always be the same in
	/// commonly-used encodings.)
	func containsASCIIString(_ searchFor: String) -> Bool {

		contains(searchFor.utf8)
	}

	/// Return true if searchFor appears in self.
	func contains(_ searchFor: Data) -> Bool {

		let searchForCount = searchFor.count
		let dataCount = self.count

		guard searchForCount > 0, searchForCount <= dataCount else {
			return false
		}

		let searchForInitialByte = searchFor[0]
		var found = false

		self.withUnsafeBytes { bytes in

			let buffer = bytes.bindMemory(to: UInt8.self)

			for i in 0...dataCount - searchForCount {

				if buffer[i] == searchForInitialByte {

					var match = true

					for j in 1..<searchForCount {

						if buffer[i + j] != searchFor[j] {
							match = false
							break
						}
					}

					if match {
						found = true
						return
					}
				}
			}
		}

		return found
	}
}
