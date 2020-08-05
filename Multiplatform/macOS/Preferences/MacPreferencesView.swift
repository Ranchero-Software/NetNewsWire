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
	@State private var selectedPane: PreferencePane = .general
	
	var body: some View {
		TabView(selection: $selectedPane) {
			GeneralPreferencesView()
				.environmentObject(defaults)
				.tabItem {
					VStack {
						Image(systemName: "gearshape")
							.font(.title2)
						Text("General")
					}
				}
				.onTapGesture {
					selectedPane = .general
				}
				.tag(PreferencePane.general)
			
			
			AccountsPreferencesView()
				.environmentObject(defaults)
				.tabItem {
					VStack {
						Image(systemName: "at")
							.font(.title2)
						Text("Accounts")
					}
				}
				.onTapGesture {
					selectedPane = .accounts
				}
				.tag(PreferencePane.accounts)
			
			LayoutPreferencesView()
				.environmentObject(defaults)
				.tabItem {
					VStack {
						Image(systemName: "eyeglasses")
							.font(.title2)
						Text("Viewing")
					}
				}
				.onTapGesture {
					selectedPane = .viewing
				}
				.tag(PreferencePane.viewing)
			
			AdvancedPreferencesView()
				.environmentObject(defaults)
				.tabItem {
					VStack {
						Image(systemName: "scale.3d")
							.font(.title2)
						Text("Advanced")
					}
				}
				.onTapGesture {
					selectedPane = .advanced
				}
				.tag(PreferencePane.advanced)
		}
		
	}
}




struct MacPreferencesView_Previews: PreviewProvider {
	static var previews: some View {
		MacPreferencesView()
	}
}
