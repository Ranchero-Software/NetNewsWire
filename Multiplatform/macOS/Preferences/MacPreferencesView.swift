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
				GeneralPreferencesView(preferences: viewModel)
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
				HStack {
					Button(action: {
						viewModel.currentPreferencePane = .general
					}, label: {
						VStack {
							Image(systemName: "gearshape")
								.font(.title2)
							Text("General")
						}.foregroundColor(
							viewModel.currentPreferencePane == .general ? Color("AccentColor") : Color.gray
						)
					}).frame(width: 70)
					Button(action: {
						viewModel.currentPreferencePane = .accounts
					}, label: {
						VStack {
							Image(systemName: "at")
								.font(.title2)
							Text("Accounts")
						}.foregroundColor(
							viewModel.currentPreferencePane == .accounts ? Color("AccentColor") : Color.gray
						)
					}).frame(width: 70)
					Button(action: {
						viewModel.currentPreferencePane = .advanced
					}, label: {
						VStack {
							Image(systemName: "scale.3d")
								.font(.title2)
							Text("Advanced")
						}.foregroundColor(
							viewModel.currentPreferencePane == .advanced ? Color("AccentColor") : Color.gray
						)
					}).frame(width: 70)
				}
			}
		}
		.preferredColorScheme(AppDefaults.userInterfaceColorScheme)
		
	}
}




struct MacPreferencesView_Previews: PreviewProvider {
	static var previews: some View {
		MacPreferencesView()
	}
}
