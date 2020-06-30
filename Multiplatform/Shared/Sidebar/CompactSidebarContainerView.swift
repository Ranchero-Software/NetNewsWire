//
//  CompactSidebarContainerView.swift
//  Multiplatform iOS
//
//  Created by Stuart Breckenridge on 29/6/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct CompactSidebarContainerView: View {
    
	@EnvironmentObject private var sceneModel: SceneModel
	@StateObject private var sidebarModel = SidebarModel()
	@State private var showSettings: Bool = false
	
	var body: some View {
		SidebarView()
			.environmentObject(sidebarModel)
			.navigationBarTitle(Text("Feeds"))
			.listStyle(PlainListStyle())
			.onAppear {
				sceneModel.sidebarModel = sidebarModel
				sidebarModel.delegate = sceneModel
				sidebarModel.rebuildSidebarItems()
			}.overlay(Group {
				#if os(iOS)
				SidebarToolbar()
				#endif
			},alignment: .bottom)
	}
	
	
	var compactToolBar: some View {
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
				Button(action: {}, label: {
					Image(systemName: "plus")
						.font(.title3)
						.foregroundColor(.accentColor)
				}).help("Add")
			}
			.padding(.horizontal, 16)
			.padding(.bottom, 12)
			.padding(.top, 4)
		}
		.background(VisualEffectBlur(blurStyle: .systemChromeMaterial).edgesIgnoringSafeArea(.bottom))
		
	}
	
	
}

struct CompactSidebarContainerView_Previews: PreviewProvider {
    static var previews: some View {
        CompactSidebarContainerView()
			.environmentObject(SceneModel())
    }
}
