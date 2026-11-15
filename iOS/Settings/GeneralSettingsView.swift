//
//  GeneralSettingsView.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 11/14/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import SwiftUI

struct GeneralSettingsView: View {

	@State private var model = GeneralSettingsModel()

	var body: some View {
		List {
			Picker(String(localized: "Color Palette", comment: "Color Palette"), selection: Binding(get: { model.colorPalette }, set: { AppDefaults.userInterfaceColorPalette = $0 })) {
				ForEach(UserInterfaceColorPalette.allCases, id: \.self) { colorPalette in
					Text(String(describing: colorPalette))
				}
			}
			.pickerStyle(.menu)
			Picker(String(localized: "Unread Counts", comment: "Unread Counts"), selection: Binding(get: { model.unreadCountDisplay }, set: { AppDefaults.unreadCountDisplay = $0 })) {
				ForEach(UnreadCountDisplay.allCases, id: \.self) { unreadCountDisplay in
					Text(String(describing: unreadCountDisplay))
				}
			}
			.pickerStyle(.menu)
			Toggle(String(localized: "Grayscale Feed Icons", comment: "Grayscale Feed Icons"), isOn: Binding(get: { model.grayscaleIcons }, set: { AppDefaults.grayscaleIcons = $0 }))
		}
		.settingsAccentTint()
		.navigationTitle(String(localized: "General", comment: "Preferences"))
	}
}

/// Tracks the General settings in AppDefaults, updating when they change.
@MainActor @Observable final class GeneralSettingsModel {

	private(set) var colorPalette = AppDefaults.userInterfaceColorPalette
	private(set) var unreadCountDisplay = AppDefaults.unreadCountDisplay
	private(set) var grayscaleIcons = AppDefaults.grayscaleIcons

	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(handleUserInterfaceColorPaletteDidUpdate(_:)), name: .userInterfaceColorPaletteDidUpdate, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleUnreadCountDisplaySettingDidChange(_:)), name: .unreadCountDisplaySettingDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleGrayscaleIconsDidChange(_:)), name: .grayscaleIconsDidChange, object: nil)
	}

	@objc func handleUserInterfaceColorPaletteDidUpdate(_ notification: Notification) {
		colorPalette = AppDefaults.userInterfaceColorPalette
	}

	@objc func handleUnreadCountDisplaySettingDidChange(_ notification: Notification) {
		unreadCountDisplay = AppDefaults.unreadCountDisplay
	}

	@objc func handleGrayscaleIconsDidChange(_ notification: Notification) {
		grayscaleIcons = AppDefaults.grayscaleIcons
	}
}
