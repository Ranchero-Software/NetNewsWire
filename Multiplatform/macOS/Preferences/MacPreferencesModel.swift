//
//  MacPreferencesModel.swift
//  Multiplatform macOS
//
//  Created by Stuart Breckenridge on 12/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation

class MacPreferencesModel {
	
	enum PreferencePane: Int, CaseIterable {
		case general = 0
		case accounts = 1
		case advanced = 2
		
		var description: String {
			switch self {
			case .general:
				return "General"
			case .accounts:
				return "Accounts"
			case .advanced:
				return "Advanced"
			}
		}
	}
	var currentPreferencePane: PreferencePane = PreferencePane.general
	
	// General Preferences
	
	
	
}
