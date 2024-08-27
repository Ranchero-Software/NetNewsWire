//
//  File.swift
//  
//
//  Created by Brent Simmons on 8/26/24.
//

import Foundation
import libxml2

func SAXEqualStrings(_ s1: XMLPointer, _ s2: XMLPointer, length: Int? = nil) -> Bool {

	if let length {
		return xmlStrncmp(s1, s2, Int32(length)) == 0
	}

	return xmlStrEqual(s1, s2) != 0
}
