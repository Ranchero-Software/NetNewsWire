//
//  SidebarView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/28/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct SidebarView: View {
	
	@EnvironmentObject private var sceneModel: SceneModel
	@StateObject private var sidebarModel = SidebarModel()
	
    var body: some View {
		List {
			ForEach(sidebarModel.sidebarItems) { section in
				OutlineGroup(sidebarModel.sidebarItems, children: \.children) { sidebarItem in
					Text(sidebarItem.nameForDisplay)
				}
			}
		}
		.navigationTitle(Text("Feeds"))
		.listStyle(SidebarListStyle())
		.onAppear {
			sceneModel.sidebarModel = sidebarModel
			sidebarModel.delegate = sceneModel
			sidebarModel.rebuildSidebarItems()
		}

	}
}

struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView()
			.environmentObject(SceneModel())
    }
}
