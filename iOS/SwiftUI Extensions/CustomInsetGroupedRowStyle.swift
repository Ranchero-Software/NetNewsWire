//
//  CustomInsetGroupedRowStyle.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 22/12/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI

struct CustomInsetGroupedRowStyle: ViewModifier {
	
	func body(content: Content) -> some View {
		content
			.padding(.horizontal, 16)
			.padding(.vertical, 8)
			.listRowInsets(EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15))
			.background(
				RoundedRectangle(cornerRadius: 8)
					.foregroundColor(Color(uiColor: UIColor.secondarySystemGroupedBackground))
			)
	}
	
}

extension View {
	
	/// This function dismisses a view when the user launches from
	/// an external action, for example, opening the app from the widget.
	/// - Returns: `View`
	func customInsetGroupedRowStyle() -> some View {
		modifier(CustomInsetGroupedRowStyle())
	}
}
