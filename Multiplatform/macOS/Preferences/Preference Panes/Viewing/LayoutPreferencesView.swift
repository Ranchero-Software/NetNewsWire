//
//  LayoutPreferencesView.swift
//  Multiplatform macOS
//
//  Created by Stuart Breckenridge on 17/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct LayoutPreferencesView: View {
    
	@StateObject private var defaults = AppDefaults.shared
	private let colorPalettes = UserInterfaceColorPalette.allCases
	private let sampleTitle = "Lorem dolor sed viverra ipsum. Gravida rutrum quisque non tellus. Rutrum tellus pellentesque eu tincidunt tortor. Sed blandit libero volutpat sed cras ornare. Et netus et malesuada fames ac. Ultrices eros in cursus turpis massa tincidunt dui ut ornare. Lacus sed viverra tellus in. Sollicitudin ac orci phasellus egestas. Purus in mollis nunc sed. Sollicitudin ac orci phasellus egestas tellus rutrum tellus pellentesque. Interdum consectetur libero id faucibus nisl tincidunt eget."
	
	var body: some View {
		
		VStack {
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
					Text("Icon size")
				}).padding(.leading, 16)
				
			}
			
			timelineRowPreview
				.frame(width: 300)
				.padding()
				.overlay(
					RoundedRectangle(cornerRadius: 8, style: .continuous)
						.stroke(Color.gray, lineWidth: 1)
				)
				.animation(.default)
				
			Text("PREVIEW")
				.font(.caption)
				.tracking(0.3)
			Spacer()
			
		}.frame(width: 400, height: 300, alignment: .center)
		
		
		
    }
	
	
	var timelineRowPreview: some View {
		HStack(alignment: .top) {
			Image(systemName: "circle.fill")
				.resizable()
				.frame(width: 10, height: 10, alignment: .top)
				.foregroundColor(.accentColor)
			
			Image(systemName: "paperplane.circle")
				.resizable()
				.frame(width: CGFloat(defaults.timelineIconDimensions), height: CGFloat(defaults.timelineIconDimensions), alignment: .top)
				.foregroundColor(.accentColor)
			
			VStack(alignment: .leading, spacing: 4) {
				Text(sampleTitle)
					.font(.headline)
					.lineLimit(Int(defaults.timelineNumberOfLines))
				HStack {
					Text("Feed Name")
						.foregroundColor(.secondary)
						.font(.footnote)
					Spacer()
					Text("10:31")
						.font(.footnote)
						.foregroundColor(.secondary)
				}
			}
		}
	}
	
	
}

struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        LayoutPreferencesView()
    }
}
