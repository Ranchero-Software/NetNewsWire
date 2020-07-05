//
//  SidebarToolbarModifier.swift
//  Multiplatform iOS
//
//  Created by Stuart Breckenridge on 30/6/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct SidebarToolbarModifier: ViewModifier {
    
	@EnvironmentObject private var appSettings: AppDefaults
	@StateObject private var viewModel = SidebarToolbarModel()

	@ViewBuilder func body(content: Content) -> some View {
		#if os(iOS)
		content
			.toolbar {
				
				ToolbarItem(placement: .navigation) {
					Button(action: {
					}, label: {
						AppAssets.filterInactiveImage
							.font(.title3)
					}).help("Filter Read Feeds")
				}
				
				ToolbarItem(placement: .automatic) {
					Button(action: {
						viewModel.sheetToShow = .settings
					}, label: {
						AppAssets.settingsImage
							.font(.title3)
					}).help("Settings")
				}
				
				ToolbarItem {
					Spacer()
				}
				
				ToolbarItem(placement: .automatic) {
					RefreshProgressView()
				}
				
				ToolbarItem {
					Spacer()
				}
				
				ToolbarItem(placement: .automatic, content: {
					Button(action: {
						viewModel.showActionSheet = true
					}, label: {
						AppAssets.addMenuImage
							.font(.title3)
					})
					.help("Add")
					.actionSheet(isPresented: $viewModel.showActionSheet) {
						ActionSheet(title: Text("Add"), buttons: [
							.cancel(),
							.default(Text("Add Web Feed"), action: { viewModel.sheetToShow = .web }),
							.default(Text("Add Twitter Feed")),
							.default(Text("Add Reddit Feed")),
							.default(Text("Add Folder"), action: { viewModel.sheetToShow = .folder })
						])
					}
				})
				
			}
			.sheet(isPresented: $viewModel.showSheet, onDismiss: { viewModel.sheetToShow = .none }) {
				if viewModel.sheetToShow == .web {
					AddWebFeedView()
				}
				if viewModel.sheetToShow == .folder {
					AddFolderView()
				}
				if viewModel.sheetToShow == .settings {
					SettingsView().modifier(PreferredColorSchemeModifier(preferredColorScheme: appSettings.userInterfaceColorPalette))
				}
			}
		#else
		content
			.toolbar {
				ToolbarItem {
					Spacer()
				}
			}
		#endif
	}
}


