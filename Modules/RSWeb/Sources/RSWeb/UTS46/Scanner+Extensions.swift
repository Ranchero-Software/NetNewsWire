//
//  Scanner+Extensions.swift
//  PunyCocoa Swift
//
//  Created by Nate Weaver on 2020-04-20.
//

import Foundation

// Wrapper functions for < 10.15 compatibility
// TODO: Remove when support for < 10.15 is dropped.
extension Scanner {

	func shimScanUpToCharacters(from set: CharacterSet) -> String? {
		if #available(macOS 10.15, iOS 13.0, *) {
			return self.scanUpToCharacters(from: set)
		} else {
			var str: NSString?
			self.scanUpToCharacters(from: set, into: &str)
			return str as String?
		}
	}

	func shimScanCharacters(from set: CharacterSet) -> String? {
		if #available(macOS 10.15, iOS 13.0, *) {
			return self.scanCharacters(from: set)
		} else {
			var str: NSString?
			self.scanCharacters(from: set, into: &str)
			return str as String?
		}
	}

	func shimScanUpToString(_ substring: String) -> String? {
		if #available(macOS 10.15, iOS 13.0, *) {
			return self.scanUpToString(substring)
		} else {
			var str: NSString?
			self.scanUpTo(substring, into: &str)
			return str as String?
		}
	}

	func shimScanString(_ searchString: String) -> String? {
		if #available(macOS 10.15, iOS 13.0, *) {
			return self.scanString(searchString)
		} else {
			var str: NSString?
			self.scanString(searchString, into: &str)
			return str as String?
		}
	}

}
