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
			Section(header: Text("label.text.icon-size", comment: "Icon Size")) {
				ZStack {
					TickMarkSliderView(minValue: 1, maxValue: 3, currentValue: Binding(get: {
						Float(appDefaults.timelineIconSize.rawValue)
					}, set: { AppDefaults.shared.timelineIconSize = IconSize(rawValue: Int($0))! }))
				}
				.customInsetGroupedRowStyle()
			}
			.listRowInsets(EdgeInsets(top: 0, leading: 30, bottom: 0, trailing: 30))
			.listRowBackground(Color.clear)
			.listRowSeparator(.hidden)
			
			Section(header: Text("label.text.number-of-lines", comment: "Number of Lines")) {
				ZStack {
					TickMarkSliderView(minValue: 1, maxValue: 5, currentValue: Binding(get: {
						Float(appDefaults.timelineNumberOfLines)
					}, set: { appDefaults.timelineNumberOfLines = Int($0) }))
				}
				.customInsetGroupedRowStyle()
			}
			.listRowInsets(EdgeInsets(top: 0, leading: 30, bottom: 0, trailing: 30))
			.listRowBackground(Color.clear)
			.listRowSeparator(.hidden)
		
			Section {
				timeLinePreviewRow
					.listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 4, trailing: 24))
			}
		}
		.listStyle(.grouped)
		.navigationTitle(Text("navigation.title.timeline-layout", comment: "Timeline Layout"))
		
    }
	
	var timeLinePreviewRow: some View {
		HStack(alignment: .top, spacing: 6) {
			VStack {
				Circle()
					.foregroundColor(Color(uiColor: AppAssets.primaryAccentColor))
					.frame(width: 12, height: 12)
				Spacer()
			}.frame(width: 12)
			VStack {
				Image("faviconTemplateImage")
					.renderingMode(.template)
					.resizable()
					.frame(width: appDefaults.timelineIconSize.size.width, height: appDefaults.timelineIconSize.size.height)
					.foregroundColor(Color(uiColor: AppAssets.primaryAccentColor))
				Spacer()
			}.frame(width: appDefaults.timelineIconSize.size.width)
			VStack(alignment: .leading, spacing: 4) {
				Text(verbatim: "Enim ut tellus elementum sagittis vitae et. Nibh praesent tristique magna sit amet purus gravida quis blandit. Neque volutpat ac tincidunt vitae semper quis lectus nulla. Massa id neque aliquam vestibulum morbi blandit. Ultrices vitae auctor eu augue. Enim eu turpis egestas pretium aenean pharetra magna. Eget gravida cum sociis natoque. Sit amet consectetur adipiscing elit. Auctor eu augue ut lectus arcu bibendum. Maecenas volutpat blandit aliquam etiam erat velit. Ut pharetra sit amet aliquam id diam maecenas ultricies. In hac habitasse platea dictumst quisque sagittis purus sit amet.")
					.bold()
					.lineLimit(appDefaults.timelineNumberOfLines)
				HStack {
					Text("label.placeholder.feed-name", comment: "Feed name")
						.foregroundColor(.secondary)
						.font(.caption)
					Spacer()
					Text(verbatim: localizedTime())
						.foregroundColor(.secondary)
						.font(.caption)
				}.padding(0)
			}
		}
		.edgesIgnoringSafeArea(.all)
		.padding(.vertical, 4)
		.padding(.leading, 4)
	}
	
	func localizedTime() -> String {
		let now = Date.now
		let formatter = DateFormatter()
		formatter.setLocalizedDateFormatFromTemplate("hh:mm")
		return formatter.string(from: now)
	}
}

struct TimelineCustomizerView_Previews: PreviewProvider {
    static var previews: some View {
        TimelineCustomizerView()
    }
}
