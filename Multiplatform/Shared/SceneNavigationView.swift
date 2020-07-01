//
//  SceneNavigationView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/28/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct SceneNavigationView: View {
    
	#if os(iOS)
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	#endif
	
	var body: some View {
		NavigationView {
			#if os(macOS)
			RegularSidebarContainerView()
				.frame(minWidth: 100, idealWidth: 150, maxHeight: .infinity)
			#else
			if horizontalSizeClass == .compact {
				CompactSidebarContainerView()
				
			} else {
				RegularSidebarContainerView()
			}
			#endif

			#if os(iOS)
			if horizontalSizeClass != .compact {
				Text("Timeline")
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			}
			#else
			Text("Timeline")
				.frame(maxWidth: .infinity, maxHeight: .infinity)
			#endif

			#if os(macOS)
			Text("None Selected")
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.toolbar { Spacer() }
			#else
			Text("None Selected")
				.frame(maxWidth: .infinity, maxHeight: .infinity)
			#endif
		}
		
	}
}

struct NavigationView_Previews: PreviewProvider {
    static var previews: some View {
		SceneNavigationView()
			.environmentObject(SceneModel())
    }
}
