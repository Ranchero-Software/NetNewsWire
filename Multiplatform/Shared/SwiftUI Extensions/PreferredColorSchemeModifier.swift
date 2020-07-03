//
//  PreferredColorSchemeModifier.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 7/3/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct PreferredColorSchemeModifier: ViewModifier {

	var preferredColorScheme: UserInterfaceColorPalette

	@ViewBuilder
	func body(content: Content) -> some View {
		switch preferredColorScheme {
		case .automatic:
			content.preferredColorScheme(nil)
		case .dark:
			content.preferredColorScheme(.dark)
		case .light:
			content.preferredColorScheme(.light)
		}
	}
	
}
