//
//  File.swift
//  
//
//  Created by Brent Simmons on 8/26/24.
//

import Foundation
import libxml2

func SAXEqualStrings(_ s1: XMLPointer, _ s2: XMLPointer, length: Int? = nil) -> Bool {

	if length == nil {
		return Bool(xmlStrEqual(s1, s2))
	}

	return xmlStrncmp(s1, s2, length) == 0
}
