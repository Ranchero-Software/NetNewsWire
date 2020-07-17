//
//  MacPreferencesView.swift
//  macOS
//
//  Created by Stuart Breckenridge on 27/6/20.
//

import SwiftUI

enum PreferencePane: Int, CaseIterable {
	case general = 0
	case accounts = 1
	case viewing = 2
	case advanced = 3
	
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

struct MacPreferencesView: View {
	
	@EnvironmentObject var defaults: AppDefaults
	@State private var preferencePane: PreferencePane = .general
	
	var body: some View {
		VStack {
			switch preferencePane {
			case .general:
				GeneralPreferencesView()
					.environmentObject(defaults)
			case .accounts:
				AccountsPreferencesView()
					.environmentObject(defaults)
			case .viewing:
				LayoutPreferencesView()
					.environmentObject(defaults)
			case .advanced:
				AdvancedPreferencesView()
					.environmentObject(defaults)
			}
		}
		.toolbar {
			ToolbarItem {
				HStack {
					Button(action: {
						preferencePane = .general
					}, label: {
						VStack {
							Image(systemName: "gearshape")
								.font(.title2)
							Text("General")
						}.foregroundColor(
							preferencePane == .general ? Color("AccentColor") : Color.gray
						)
					}).frame(width: 70, height: 50)
					Button(action: {
						preferencePane = .accounts
					}, label: {
						VStack {
							Image(systemName: "at")
								.font(.title2)
							Text("Accounts")
						}.foregroundColor(
							preferencePane == .accounts ? Color("AccentColor") : Color.gray
						)
					}).frame(width: 70, height: 50)
					Button(action: {
						preferencePane = .viewing
					}, label: {
						VStack {
							Image(systemName: "eyeglasses")
								.font(.title2)
							Text("Viewing")
						}.foregroundColor(
							preferencePane == .viewing ? Color("AccentColor") : Color.gray
						)
					}).frame(width: 70, height: 50)
					Button(action: {
						preferencePane = .advanced
					}, label: {
						VStack {
							Image(systemName: "scale.3d")
								.font(.title2)
							Text("Advanced")
						}.foregroundColor(
							preferencePane == .advanced ? Color("AccentColor") : Color.gray
						)
					}).frame(width: 70, height: 50)
				}
			}
		}
		
	}
}




struct MacPreferencesView_Previews: PreviewProvider {
	static var previews: some View {
		MacPreferencesView()
	}
}
