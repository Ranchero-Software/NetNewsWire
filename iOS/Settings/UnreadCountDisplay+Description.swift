//
//  UnreadCountDisplay+Description.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/6/26.
//

import Foundation

extension UnreadCountDisplay: CustomStringConvertible {

	var description: String {
		switch self {
		case .count:
			NSLocalizedString("Show", comment: "Show")
		case .dot:
			NSLocalizedString("Show dot", comment: "Unread Counts setting: show a dot instead of the number of unread articles")
		case .hidden:
			NSLocalizedString("Hide", comment: "Hide")
		}
	}
}
