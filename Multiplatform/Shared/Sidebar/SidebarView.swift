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
        Text("Sidebar")
			.onAppear {
				sceneModel.sidebarModel = sidebarModel
				sidebarModel.delegate = sceneModel
			}

//		List {
//			ForEach(canvases) { canvas in
//				Section(header: Text(canvas.name)) {
//					OutlineGroup(canvas.graphics, children: \.children)
//					{ graphic in
//						GraphicRow(graphic)
//					}
//				}
//			}
//		}
		
	}
}

struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView()
    }
}
