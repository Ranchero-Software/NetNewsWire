//
//  MarkArticleAsReadMode.swift
//  NetNewsWire
//

import Foundation

/// How articles become read.
enum MarkArticleAsReadMode: Int, CaseIterable, CustomStringConvertible {
	case onOpen = 1
	case manually = 0

	var description: String {
		switch self {
		case .onOpen:
			NSLocalizedString("On open", comment: "Mark article as read setting")
		case .manually:
			NSLocalizedString("Manually", comment: "Mark article as read setting")
		}
	}
}
