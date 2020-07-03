//
//  SidebarToolbar.swift
//  Multiplatform iOS
//
//  Created by Stuart Breckenridge on 30/6/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

fileprivate enum ToolbarSheets {
	case none, web, twitter, reddit, folder, settings
}

fileprivate class SidebarViewModel: ObservableObject {
	
	@Published var showSheet: Bool = false
	@Published var sheetToShow: ToolbarSheets = .none {
		didSet {
			sheetToShow != .none ? (showSheet = true) : (showSheet = false)
		}
	}
	@Published var showActionSheet: Bool = false
	@Published var showAddSheet: Bool = false
}


struct SidebarToolbar: View {
    
	@EnvironmentObject private var appSettings: AppDefaults
	@StateObject private var viewModel = SidebarViewModel()


	var addActionSheetButtons = [
		Button(action: {}, label: { Text("Add Feed") })
	]
	
	var body: some View {
		VStack {
			Divider()
			HStack(alignment: .center) {
				Button(action: {
					viewModel.sheetToShow = .settings
				}, label: {
					Image(systemName: "gear")
						.font(.title3)
						.foregroundColor(.accentColor)
				}).help("Settings")
				
				Spacer()
				
				Text("Last updated")
					.font(.caption)
					.foregroundColor(.secondary)
				
				Spacer()
				
				Button(action: {
					viewModel.showActionSheet = true
				}, label: {
					Image(systemName: "plus")
						.font(.title3)
						.foregroundColor(.accentColor)
				})
				.help("Add")
				.actionSheet(isPresented: $viewModel.showActionSheet) {
					ActionSheet(title: Text("Add"), buttons: [
						.cancel(),
						.default(Text("Add Web Feed"), action: { viewModel.sheetToShow = .web }),
						.default(Text("Add Twitter Feed")),
						.default(Text("Add Reddit Feed")),
						.default(Text("Add Folder"))
					])
				}
			}
			.padding(.horizontal, 16)
			.padding(.bottom, 12)
			.padding(.top, 4)
		}
		.background(VisualEffectBlur(blurStyle: .systemChromeMaterial).edgesIgnoringSafeArea(.bottom))
		.sheet(isPresented: $viewModel.showSheet, onDismiss: { viewModel.sheetToShow = .none }) {
			if viewModel.sheetToShow == .web {
				AddWebFeedView()
			}
			if viewModel.sheetToShow == .settings {
				SettingsView().modifier(PreferredColorSchemeModifier(preferredColorScheme: appSettings.userInterfaceColorPalette))
			}
		}
	
    }
}

struct SidebarToolbar_Previews: PreviewProvider {
    static var previews: some View {
        SidebarToolbar()
    }
}
