//
//  SidebarView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/28/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct RegularSidebarContainerView: View {
	
	@EnvironmentObject private var sceneModel: SceneModel
	@StateObject private var sidebarModel = SidebarModel()
	
	@State private var showSettings: Bool = false
	
    @ViewBuilder var body: some View {
		SidebarView()
			.environmentObject(sidebarModel)
			.navigationTitle(Text("Feeds"))
			.listStyle(SidebarListStyle())
			.onAppear {
				sceneModel.sidebarModel = sidebarModel
				sidebarModel.delegate = sceneModel
				sidebarModel.rebuildSidebarItems()
			}
			.overlay(Group {
				#if os(iOS)
				SidebarToolbar()
				#endif
			},alignment: .bottom)
		
	}
	
}

struct RegularSidebarContainerView_Previews: PreviewProvider {
    static var previews: some View {
        RegularSidebarContainerView()
			.environmentObject(SceneModel())
    }
}
