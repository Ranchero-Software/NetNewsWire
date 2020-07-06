//
//  TimelineLayoutView.swift
//  Multiplatform iOS
//
//  Created by Stuart Breckenridge on 1/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct TimelineLayoutView: View {
    
	@EnvironmentObject private var defaults: AppDefaults
	
	private let sampleTitle = "Lorem dolor sed viverra ipsum. Gravida rutrum quisque non tellus. Rutrum tellus pellentesque eu tincidunt tortor. Sed blandit libero volutpat sed cras ornare. Et netus et malesuada fames ac. Ultrices eros in cursus turpis massa tincidunt dui ut ornare. Lacus sed viverra tellus in. Sollicitudin ac orci phasellus egestas. Purus in mollis nunc sed. Sollicitudin ac orci phasellus egestas tellus rutrum tellus pellentesque. Interdum consectetur libero id faucibus nisl tincidunt eget."
	
	var body: some View {
		VStack(spacing: 0) {
			List {
				Section(header: Text("Icon Size"), content: {
					iconSize
				})
				Section(header: Text("Number of Lines"), content: {
					numberOfLines
				})			}
			.listStyle(InsetGroupedListStyle())
			
			Divider()
			timelineRowPreview.padding()
			Divider()
		}
		.navigationBarTitle("Timeline Layout")
    }
	
	var iconSize: some View {
		Slider(value: $defaults.timelineIconDimensions, in: 20...60, step: 10, minimumValueLabel: Text("Small"), maximumValueLabel: Text("Large"), label: {
			Text(String(defaults.timelineIconDimensions))
		})
	}
	
	var numberOfLines: some View {
		Slider(value: $defaults.timelineNumberOfLines, in: 1...5, step: 1, minimumValueLabel: Text("1"), maximumValueLabel: Text("5"), label: {
			Text("Article Title")
		})
		
		
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

struct TimelineLayout_Previews: PreviewProvider {
    static var previews: some View {
		TimelineLayoutView()
    }
}
