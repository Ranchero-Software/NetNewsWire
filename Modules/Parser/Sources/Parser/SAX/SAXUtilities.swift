//
//  SAXUtilities.swift
//  
//
//  Created by Brent Simmons on 8/26/24.
//

import Foundation
import libxml2

public func SAXEqualTags(_ localName: XMLPointer, _ tag: ContiguousArray<Int8>) -> Bool {

	return tag.withUnsafeBufferPointer { bufferPointer in
		
		let tagCount = tag.count // includes 0 terminator

		for i in 0..<tagCount - 1 {

			let localNameCharacter = localName[i]
			if localNameCharacter == 0 {
				return false
			}

			let tagCharacter = UInt8(tag[i])
			if localNameCharacter != tagCharacter {
				return false
			}
		}

		// localName might actually be longer — make sure it’s the same length as tag.
		return localName[tagCount - 1] == 0
	}
}

public extension String {

	init?(xmlPointer: XMLPointer, count: Int? = nil) {
		let d = Data(bytes: xmlPointer, count: count ?? strlen(xmlPointer))
		self.init(data: d, encoding: .utf8)
	}
}
