//
//  CompactNavigationView.swift
//  Multiplatform iOS
//
//  Created by Stuart Breckenridge on 29/6/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct CompactNavigationView: View {
    
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
		.navigationBarTitle(Text("Feeds"))
		.listStyle(PlainListStyle())
		.onAppear {
			sceneModel.sidebarModel = sidebarModel
			sidebarModel.delegate = sceneModel
			sidebarModel.rebuildSidebarItems()
		}

	}
	
	
}

struct CompactSidebarView_Previews: PreviewProvider {
    static var previews: some View {
        CompactNavigationView()
    }
}
