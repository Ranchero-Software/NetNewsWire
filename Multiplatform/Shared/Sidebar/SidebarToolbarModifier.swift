//
//  SidebarToolbarModifier.swift
//  Multiplatform iOS
//
//  Created by Stuart Breckenridge on 30/6/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct SidebarToolbarModifier: ViewModifier {
    
	@EnvironmentObject private var sidebarModel: SidebarModel
	@EnvironmentObject private var defaults: AppDefaults
	@StateObject private var viewModel = SidebarToolbarModel()

	@ViewBuilder func body(content: Content) -> some View {
		#if os(iOS)
		content
			.toolbar {
				
				ToolbarItem(placement: .navigation) {
					Button {
						withAnimation {
							sidebarModel.isReadFiltered.toggle()
						}
					} label: {
						if sidebarModel.isReadFiltered {
							AppAssets.filterActiveImage.font(.title3)
						} else {
							AppAssets.filterInactiveImage.font(.title3)
						}
					}
					.help(sidebarModel.isReadFiltered ? "Show Read Feeds" : "Filter Read Feeds")
				}
				
				ToolbarItem(placement: .automatic) {
					Button {
						viewModel.sheetToShow = .settings
					} label: {
						AppAssets.settingsImage.font(.title3)
					}
					.help("Settings")
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
					Button {
						viewModel.showActionSheet = true
					} label: {
						AppAssets.addMenuImage.font(.title3)
					}
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
					SettingsView().modifier(PreferredColorSchemeModifier(preferredColorScheme: defaults.userInterfaceColorPalette))
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


