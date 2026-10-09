//
//  ReaderAPIVariant.swift
//  
//
//  Created by Maurice Parker on 10/23/20.
//

import Foundation

nonisolated public enum ReaderAPIVariant: Sendable {
	case generic
	case freshRSS
	case inoreader
	case bazQux
	case theOldReader
	case wordpressCom

	public var host: String {
		switch self {
		case .inoreader:
			return "https://www.inoreader.com"
		case .bazQux:
			return "https://bazqux.com"
		case .theOldReader:
			return "https://theoldreader.com"
		case .wordpressCom:
			return "https://public-api.wordpress.com/wpcom/v2/reader/greader"
		default:
			return ""
		}
	}
}
