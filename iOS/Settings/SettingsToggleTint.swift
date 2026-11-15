//
//  SettingsToggleTint.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 11/14/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import SwiftUI

extension View {

	/// Gives Settings switches the app’s accent color, matching the rest of the app’s switches.
	func settingsToggleTint() -> some View {
		tint(Color(uiColor: Assets.Colors.primaryAccent))
	}
}
