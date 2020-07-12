//
//  SidebarContainerView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/28/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct SidebarContainerView: View {
	
	@Environment(\.undoManager) var undoManager
	@EnvironmentObject private var sceneModel: SceneModel
	
	@State private var showSettings: Bool = false
	
    @ViewBuilder var body: some View {
		SidebarView()
			.modifier(SidebarToolbarModifier())
			.modifier(SidebarListStyleModifier())
			.environmentObject(sceneModel.sidebarModel)
			.onAppear {
				sceneModel.sidebarModel.undoManager = undoManager
				sceneModel.sidebarModel.rebuildSidebarItems()
			}
	}
	
}

struct SidebarContainerView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarContainerView()
			.environmentObject(SceneModel())
    }
}
