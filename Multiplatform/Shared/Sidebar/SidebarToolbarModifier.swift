//
//  SidebarToolbarModifier.swift
//  Multiplatform iOS
//
//  Created by Stuart Breckenridge on 30/6/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct SidebarToolbarModifier: ViewModifier {
    
	@EnvironmentObject private var refreshProgress: RefreshProgressModel
	@EnvironmentObject private var defaults: AppDefaults
	@EnvironmentObject private var sidebarModel: SidebarModel
	@EnvironmentObject private var sceneNavigationModel: SceneNavigationModel
	@StateObject private var viewModel = SidebarToolbarModel()

	@ViewBuilder func body(content: Content) -> some View {
		#if os(iOS)
		content
			.toolbar {
				
				ToolbarItem(placement: .primaryAction) {
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
				
				ToolbarItem(placement: .bottomBar) {
					Button {
						viewModel.sheetToShow = .settings
					} label: {
						AppAssets.settingsImage.font(.title3)
					}
					.help("Settings")
				}
				
				ToolbarItem(placement: .bottomBar) {
					Spacer()
				}
				
				ToolbarItem(placement: .bottomBar) {
					switch refreshProgress.state {
					case .refreshProgress(let progress):
						ProgressView(value: progress)
							.frame(width: 100)
					case .lastRefreshDateText(let text):
						Text(text)
							.lineLimit(1)
							.font(.caption)
							.foregroundColor(.secondary)
					case .none:
						EmptyView()
					}
				}
				
				ToolbarItem(placement: .bottomBar) {
					Spacer()
				}
				
				ToolbarItem(placement: .bottomBar, content: {
					Menu(content: {
						Button { viewModel.sheetToShow = .web } label: { Text("Add Web Feed") }
						Button { viewModel.sheetToShow = .twitter } label: { Text("Add Twitter Feed") }
						Button { viewModel.sheetToShow = .reddit } label: { Text("Add Reddit Feed") }
						Button { viewModel.sheetToShow = .folder } label: { Text("Add Folder") }
					}, label: {
						AppAssets.addMenuImage.font(.title3)
					})
				})
				
			}
			.sheet(isPresented: $viewModel.showSheet, onDismiss: { viewModel.sheetToShow = .none }) {
				if viewModel.sheetToShow == .web {
					AddWebFeedView(isPresented: $viewModel.showSheet)
				}
				if viewModel.sheetToShow == .folder {
					AddFolderView(isPresented: $viewModel.showSheet)
				}
				if viewModel.sheetToShow == .settings {
					SettingsView()
						.preferredColorScheme(AppDefaults.userInterfaceColorScheme)
				}
			}
		#else
		content
			.toolbar {
				ToolbarItem {
					Spacer()
				}
				ToolbarItem(placement: .automatic) {
					Button {
						AccountManager.shared.refreshAll(completion: nil)
						
					} label: {
						AppAssets.refreshImage
					}
					.help("Refresh")
				}
				ToolbarItem(placement: .automatic) {
					Menu {
						Button("Add Web Feed", action: { sceneNavigationModel.sheetToShow = .web })
						Button("Add Reddit Feed", action:  { })
						Button("Add Twitter Feed", action:  { })
						Button("Add Folder", action:  { sceneNavigationModel.sheetToShow = .folder})
					} label : {
						AppAssets.addMenuImage
					}
				}
			}
		#endif
	}
}


