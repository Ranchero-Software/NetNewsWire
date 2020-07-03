//
//  SidebarToolbar.swift
//  Multiplatform iOS
//
//  Created by Stuart Breckenridge on 30/6/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct SidebarToolbar: View {
    
	enum ToolbarSheets {
		case none, web, twitter, reddit, folder, settings
	}
	
	@State private var showSheet: Bool = false
	@State private var sheetToShow: ToolbarSheets = .none {
		didSet {
			sheetToShow != .none ? (showSheet = true) : (showSheet = false)
		}
	}
	@State private var showActionSheet: Bool = false

	var addActionSheetButtons = [
		Button(action: {}, label: { Text("Add Feed") })
	]
	
	var body: some View {
		VStack {
			Divider()
			HStack(alignment: .center) {
				Button(action: {
					sheetToShow = .settings
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
					showActionSheet = true
				}, label: {
					Image(systemName: "plus")
						.font(.title3)
						.foregroundColor(.accentColor)
				})
				.help("Add")
				.actionSheet(isPresented: $showActionSheet) {
					ActionSheet(title: Text("Add"), buttons: [
						.cancel(),
						.default(Text("Add Web Feed"), action: { sheetToShow = .web }),
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
		.sheet(isPresented: $showSheet, onDismiss: { sheetToShow = .none }) {
			switch sheetToShow {
			case .web:
				AddWebFeedView()
			default:
				EmptyView()
			}
		}
	
    }
}

struct SidebarToolbar_Previews: PreviewProvider {
    static var previews: some View {
        SidebarToolbar()
    }
}
