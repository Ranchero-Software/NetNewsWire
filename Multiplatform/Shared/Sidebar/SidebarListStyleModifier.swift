//
//  SidebarListStyleModifier.swift
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
		#if os(macOS)
		content
			.listStyle(.sidebar)
		#else
		if horizontalSizeClass == .compact {
			content
				.listStyle(.plain)
		} else {
			content
				.listStyle(.sidebar)
		}
		#endif
		
	}

}
