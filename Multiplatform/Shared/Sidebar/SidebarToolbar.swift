//
//  SidebarToolbar.swift
//  Multiplatform iOS
//
//  Created by Stuart Breckenridge on 30/6/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct SidebarToolbar: View {
    
	@State private var showSettings: Bool = false
	@State private var showAddSheet: Bool = false

	var addActionSheetButtons = [
		Button(action: {}, label: { Text("Add Feed") })
	]
	
	var body: some View {
		VStack {
			Divider()
			HStack(alignment: .center) {
				Button(action: {
					showSettings = true
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
					showAddSheet = true
				}, label: {
					Image(systemName: "plus")
						.font(.title3)
						.foregroundColor(.accentColor)
				})
				.help("Add")
				.actionSheet(isPresented: $showAddSheet) {
					ActionSheet(title: Text("Add"), buttons: [
						.cancel(),
						.default(Text("Add Web Feed")),
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
		.sheet(isPresented: $showSettings, onDismiss: { showSettings = false }) {
			SettingsView()
		}
	
    }
}

struct SidebarToolbar_Previews: PreviewProvider {
    static var previews: some View {
        SidebarToolbar()
    }
}
