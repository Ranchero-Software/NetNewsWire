//
//  NavigationView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/28/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct SceneNavigationView: View {
    var body: some View {
		SceneNavigationView {
			Text("Hello")
//			#if os(macOS)
//			SidebarView().frame(minWidth: 100, idealWidth: 150, maxWidth: 200, maxHeight: .infinity)
//			#else
//			SidebarView()
//			#endif
//
//			Text("Timeline")
//				.frame(maxWidth: .infinity, maxHeight: .infinity)
//
//			#if os(macOS)
//			Text("None Selected")
//				.frame(maxWidth: .infinity, maxHeight: .infinity)
//				.toolbar { Spacer() }
//			#else
//			Text("None Selected")
//				.frame(maxWidth: .infinity, maxHeight: .infinity)
//			#endif
		}
	}
}

struct NavigationView_Previews: PreviewProvider {
    static var previews: some View {
        SceneNavigationView()
    }
}
