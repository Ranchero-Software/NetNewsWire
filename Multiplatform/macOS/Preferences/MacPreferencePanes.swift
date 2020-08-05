//
//  MacPreferencesView.swift
//  macOS
//
//  Created by Stuart Breckenridge on 27/6/20.
//

import SwiftUI

enum MacPreferencePane: Int, CaseIterable {
	case general = 1
	case accounts = 2
	case viewing = 3
	case advanced = 4
	
	var description: String {
		switch self {
		case .general:
			return "General"
		case .accounts:
			return "Accounts"
		case .viewing:
			return "Appearance"
		case .advanced:
			return "Advanced"
		}
	}
}
