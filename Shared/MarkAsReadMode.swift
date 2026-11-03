//
//  MarkAsReadMode.swift
//  NetNewsWire
//

import Foundation

/// How articles become read.
enum MarkAsReadMode: Int, CaseIterable, CustomStringConvertible {
	// Raw values preserve the original Boolean setting: true/1 = onOpen, false/0 = manually.
	case onOpen = 1
	case manually = 0

	var description: String {
		switch self {
		case .onOpen:
			NSLocalizedString("On Open", comment: "Mark as Read setting")
		case .manually:
			NSLocalizedString("Manually", comment: "Mark as Read setting")
		}
	}
}
