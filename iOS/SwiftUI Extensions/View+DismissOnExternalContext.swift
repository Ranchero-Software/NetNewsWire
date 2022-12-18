//
//  View+DismissOnExternalContext.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 18/12/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI


struct DismissOnExternalContext: ViewModifier {
	
	@Environment(\.dismiss) private var dismiss
	
	func body(content: Content) -> some View {
		content
			.onReceive(NotificationCenter.default.publisher(for: .LaunchedFromExternalAction)) { _ in
			dismiss()
		}
	}
	
}

extension View {
	
	/// This function dismisses a view when the user launches from
	/// an external action, for example, opening the app from the widget.
	/// - Returns: `View`
	func dismissOnExternalContextLaunch() -> some View {
		modifier(DismissOnExternalContext())
	}
}
