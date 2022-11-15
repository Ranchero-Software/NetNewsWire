//
//  ReadMarkInterval.swift
//  NetNewsWire
//
//  Created by Mickael Belhassen on 15/11/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import Foundation

enum ReadMarkInterval: Int, CaseIterable, Identifiable {
	case immediately = 0, after1 = 1, after2 = 2, after4 = 4, after8 = 8

	var second: TimeInterval {
		switch self {
			default:
				return TimeInterval(rawValue)
		}
	}

	var id: String { description() }

	func description() -> String {
		switch self {
			case .immediately:
				return NSLocalizedString("Immediately", comment: "Immediately")
			case .after1:
				return NSLocalizedString("After 1 second", comment: "After 1 second")
			case .after2:
				return NSLocalizedString("After 2 seconds", comment: "After 2 seconds")
			case .after4:
				return NSLocalizedString("After 4 seconds", comment: "After 4 seconds")
			case .after8:
				return NSLocalizedString("After 8 seconds", comment: "Every 8 Hours")
		}
	}
}
