//
//  SidebarStyleModifier.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 7/6/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct SidebarListStyleModifier: ViewModifier {
	
	#if os(iOS)
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	#endif

	@ViewBuilder func body(content: Content) -> some View {
		content
		#if os(macOS)
		content
			.listStyle(SidebarListStyle())
		#else
		if horizontalSizeClass == .compact {
			content
				.listStyle(PlainListStyle())
		} else {
			content
				.listStyle(SidebarListStyle())
		}
		#endif
		
	}

}
