//
//  TimelineCustomizerView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 20/12/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI


struct TimelineCustomizerView: View {
	
	@StateObject private var appDefaults = AppDefaults.shared
	
    var body: some View {
		List {
			Section(header: Text("ICON_SIZE", tableName: "Settings")) {
				Slider(value: Binding(get: { Float(appDefaults.timelineIconSize.rawValue) },
									  set: { appDefaults.timelineIconSize = IconSize(rawValue: Int($0))! }),
					   in: Float(IconSize.small.rawValue)...Float(IconSize.large.rawValue),
					   step: 1,
					   label: { Text("ICON_SIZE", tableName: "Settings") },
					   onEditingChanged: { _ in
				})
				.tint(Color(uiColor: AppAssets.primaryAccentColor))
				.padding(.horizontal, 16)
				.padding(.vertical, 8)
				.listRowInsets(EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15))
				.background(
					RoundedRectangle(cornerRadius: 8)
						.foregroundColor(Color(uiColor: UIColor.systemBackground))
				)
				
			}
			.listRowInsets(EdgeInsets(top: 0, leading: 30, bottom: 0, trailing: 30))
			.listRowBackground(Color.clear)
			.listRowSeparator(.hidden)
			
			Section(header: Text("NUMBER_OF_LINES", tableName: "Settings")) {
				Slider(value: Binding(get: { Float(appDefaults.timelineNumberOfLines) },
									  set: { appDefaults.timelineNumberOfLines = Int($0) }),
					   in: 1...5,
					   step: 1,
					   label: { Text("NUMBER_OF_LINES", tableName: "Settings") },
					   onEditingChanged: { _ in
				})
				.tint(Color(uiColor: AppAssets.primaryAccentColor))
				.padding(.horizontal, 16)
				.padding(.vertical, 8)
				.listRowInsets(EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15))
				.background(
					RoundedRectangle(cornerRadius: 8)
						.foregroundColor(Color(uiColor: UIColor.systemBackground))
				)
			}
			.listRowInsets(EdgeInsets(top: 0, leading: 30, bottom: 0, trailing: 30))
			.listRowBackground(Color.clear)
			.listRowSeparator(.hidden)
		
			Section {
				timeLinePreviewRow
					.listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 28))
			}
		}
		.listStyle(.grouped)
		.navigationTitle(Text("TIMELINE_LAYOUT", tableName: "Settings"))
    }
	
	var timeLinePreviewRow: some View {
		HStack(spacing: 6) {
			VStack {
				Circle()
					.foregroundColor(Color(uiColor: AppAssets.primaryAccentColor))
					.frame(width: 12, height: 12)
				Spacer()
			}.frame(width: 12)
			VStack {
				Image(systemName: "globe.europe.africa.fill")
					.resizable()
					.frame(width: appDefaults.timelineIconSize.size.width, height: appDefaults.timelineIconSize.size.height)
					.foregroundColor(Color(uiColor: AppAssets.primaryAccentColor))
				Spacer()
			}.frame(width: appDefaults.timelineIconSize.size.width)
			VStack(spacing: 4) {
				Text("Enim ut tellus elementum sagittis vitae et. Nibh praesent tristique magna sit amet purus gravida quis blandit. Neque volutpat ac tincidunt vitae semper quis lectus nulla. Massa id neque aliquam vestibulum morbi blandit. Ultrices vitae auctor eu augue. Enim eu turpis egestas pretium aenean pharetra magna. Eget gravida cum sociis natoque. Sit amet consectetur adipiscing elit. Auctor eu augue ut lectus arcu bibendum. Maecenas volutpat blandit aliquam etiam erat velit. Ut pharetra sit amet aliquam id diam maecenas ultricies. In hac habitasse platea dictumst quisque sagittis purus sit amet.")
					.bold()
					.lineLimit(appDefaults.timelineNumberOfLines)
				HStack {
					Text("Feed name")
						.foregroundColor(.secondary)
						.font(.caption)
					Spacer()
					Text("08:51")
						.foregroundColor(.secondary)
						.font(.caption)
				}.padding(0)
			}
		}
		.edgesIgnoringSafeArea(.all)
		.padding(.vertical, 4)
		.padding(.leading, 4)
		
	}
	
	
}

struct TimelineCustomizerView_Previews: PreviewProvider {
    static var previews: some View {
        TimelineCustomizerView()
    }
}
