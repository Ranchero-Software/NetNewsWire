//
//  String+RSWeb.swift
//  RSWeb
//
//  Created by Brent Simmons on 1/13/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import Foundation

public extension String {

	/// Escapes special HTML characters.
	///
	/// Escaped characters are `&`, `<`, `>`, `"`, and `'`.
	var escapedHTML: String {
		var escaped = String()

		for char in self {
			switch char {
			case "&":
				escaped.append("&amp;")
			case "<":
				escaped.append("&lt;")
			case ">":
				escaped.append("&gt;")
			case "\"":
				escaped.append("&quot;")
			case "'":
				escaped.append("&apos;")
			default:
				escaped.append(char)
			}
		}

		return escaped
	}
}
