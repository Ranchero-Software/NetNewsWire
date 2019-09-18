//
//  VibrantSelectAction.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/15/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import SwiftUI

struct VibrantSelectAction: ViewModifier {
	
	let action: () -> Void
	@State var isTapped = false
	@GestureState var isLongPressed = false
	
	func body(content: Content) -> some View {
		GeometryReader { geometry in
			content
				.frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
				.background(self.isLongPressed || self.isTapped ? Color(AppAssets.primaryAccentColor) : Color(.secondarySystemGroupedBackground))
		}
		.foregroundColor(isLongPressed || isTapped ? Color(AppAssets.tableViewCellHighlightedTextColor) : .primary)
		.listRowBackground(isLongPressed || isTapped ? Color(AppAssets.primaryAccentColor) : nil)
		.gesture(
			LongPressGesture().onEnded( { _ in self.action() })
				.updating($isLongPressed) { value, state, transcation in state = value	}
				.simultaneously(with:
					TapGesture().onEnded( {
						self.isTapped = true
						self.action()
						DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
							self.isTapped = false
						}
					}
				))
		)
	}
	
}
