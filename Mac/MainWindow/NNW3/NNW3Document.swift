//
//  NNW3Document.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 10/14/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation

class NNW3Document: NNW3Entry {
	
	init(plist: [[String: Any]]) {
		super.init(title: "NNW3")
		
		for child in plist {
			if child["isContainer"] as? Bool ?? false {
				entries.append(NNW3Entry(plist: child, parent: self))
			} else {
				entries.append(NNW3Feed(plist: child, parent: self))
			}
		}
		
	}
	
	override func makeXML(indentLevel: Int) -> String {
		
		var s =
		"""
		<?xml version="1.0" encoding="UTF-8"?>
		<opml version="1.1">
		<head>
		<title>\(title ?? "")</title>
		</head>
		<body>
		
		"""
		
		for entry in entries {
			s += entry.makeXML(indentLevel: indentLevel + 1)
		}

		s +=
		"""
			</body>
			</opml>
			"""
		
		return s
		
	}
	
}
