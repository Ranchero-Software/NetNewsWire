//
//  ColorPaletteContainerView.swift
//  Multiplatform iOS
//
//  Created by Rizwan on 02/07/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct ColorPaletteContainerView: View {
	private let colorPalettes = UserInterfaceColorPalette.allCases
	@EnvironmentObject private var appSettings: AppDefaults
	@Environment(\.presentationMode) var presentationMode

	var body: some View {
		List {
			ForEach.init(0 ..< colorPalettes.count) { index in
				Button(action: {
					onTapColorPalette(at:index)
				}) {
					ColorPaletteView(colorPalette: colorPalettes[index])
				}
			}
		}
		.listStyle(InsetGroupedListStyle())
		.navigationBarTitle("Color Palette", displayMode: .inline)
    }

	func onTapColorPalette(at index: Int) {
		if let colorPalette = UserInterfaceColorPalette(rawValue: index) {
			appSettings.userInterfaceColorPalette = colorPalette
		}
		self.presentationMode.wrappedValue.dismiss()
	}
}

struct ColorPaletteView: View {
	var colorPalette: UserInterfaceColorPalette
	@EnvironmentObject private var appSettings: AppDefaults

	var body: some View {
		HStack {
			Text(colorPalette.description).foregroundColor(.primary)
			Spacer()
			if colorPalette == appSettings.userInterfaceColorPalette {
				Image(systemName: "checkmark")
					.foregroundColor(.blue)
			}
		}
	}
}

struct ColorPaletteContainerView_Previews: PreviewProvider {
    static var previews: some View {
		NavigationView {
			ColorPaletteContainerView()
		}
    }
}
