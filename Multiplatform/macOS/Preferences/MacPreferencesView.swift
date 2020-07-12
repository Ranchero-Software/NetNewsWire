//
//  MacPreferencesView.swift
//  macOS
//
//  Created by Stuart Breckenridge on 27/6/20.
//

import SwiftUI


struct MacPreferencesView: View {
	
	@EnvironmentObject var defaults: AppDefaults
	@StateObject private var viewModel = MacPreferencesModel()
	
	var body: some View {
		VStack {
			switch viewModel.currentPreferencePane {
			case .general:
				GeneralPreferencesView()
					.environmentObject(defaults)
			case .accounts:
				AccountsPreferencesView()
					.environmentObject(defaults)
			case .advanced:
				AdvancedPreferencesView()
					.environmentObject(defaults)
			}
		}
		.toolbar {
			ToolbarItem {
				Button(action: {
					viewModel.currentPreferencePane = .general
				}, label: {
					Image(systemName: "checkmark.rectangle")
					Text("General")
				})
			}
			ToolbarItem {
				Button(action: {
					viewModel.currentPreferencePane = .accounts
				}, label: {
					Image(systemName: "network")
					Text("Accounts")
				})
			}
			ToolbarItem {
				Button(action: {
					viewModel.currentPreferencePane = .advanced
				}, label: {
					Image(systemName: "gearshape.fill")
					Text("Advanced")
				})
			}
		}
		.presentedWindowToolbarStyle(UnifiedCompactWindowToolbarStyle())
		.presentedWindowStyle(TitleBarWindowStyle())
		.navigationTitle(Text(viewModel.currentPreferencePane.description))
	}
}




struct MacPreferencesView_Previews: PreviewProvider {
	static var previews: some View {
		MacPreferencesView()
	}
}
