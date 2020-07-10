//
//  SidebarContainerView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/28/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct SidebarContainerView: View {
	
	@EnvironmentObject private var sceneModel: SceneModel
	@StateObject private var sidebarModel = SidebarModel()
	
	@State private var showSettings: Bool = false
	
    @ViewBuilder var body: some View {
		SidebarView()
			.modifier(SidebarToolbarModifier())
			.modifier(SidebarListStyleModifier())
			.environmentObject(sidebarModel)
			.navigationTitle(Text("Feeds"))
			.onAppear {
				sceneModel.sidebarModel = sidebarModel
				sidebarModel.delegate = sceneModel
				sidebarModel.rebuildSidebarItems()
			}
	}
	
}

struct SidebarContainerView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarContainerView()
			.environmentObject(SceneModel())
    }
}
