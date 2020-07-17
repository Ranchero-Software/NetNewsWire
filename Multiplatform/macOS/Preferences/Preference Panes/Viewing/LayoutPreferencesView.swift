//
//  LayoutPreferencesView.swift
//  Multiplatform macOS
//
//  Created by Stuart Breckenridge on 17/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct LayoutPreferencesView: View {
    
	@EnvironmentObject var defaults: AppDefaults
	private let colorPalettes = UserInterfaceColorPalette.allCases
	
	var body: some View {
		Form {
			Picker("Appearance", selection: $defaults.userInterfaceColorPalette, content: {
				ForEach(colorPalettes, id: \.self, content: {
					Text($0.description)
				})
			})
			
			Divider()
			
			Text("Timeline: ")
			Picker("Number of Lines", selection: $defaults.timelineNumberOfLines, content: {
				ForEach(1..<6, content: { i in
					Text(String(i))
						.tag(Double(i))
				})
			}).padding(.leading, 16)
			Slider(value: $defaults.timelineIconDimensions, in: 20...60, step: 10, minimumValueLabel: Text("Small"), maximumValueLabel: Text("Large"), label: {
				Text("Icon Size")
			}).padding(.leading, 16)
		}
		.frame(width: 400, alignment: .center)
    }
}

struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        LayoutPreferencesView()
    }
}
