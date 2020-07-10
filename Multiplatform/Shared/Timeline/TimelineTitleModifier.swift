//
//  TimelineTitleModifier.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 7/6/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct TimelineTitleModifier: ViewModifier {
	
	var title: String
	
	func body(content: Content) -> some View {
		#if os(macOS)
		return content
		#endif
		#if os(iOS)
		return content.navigationBarTitle(Text(verbatim: title), displayMode: .inline)
		#endif
	}
}
