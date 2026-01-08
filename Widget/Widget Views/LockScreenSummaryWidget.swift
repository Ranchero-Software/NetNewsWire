//
//  LockScreenSummaryWidgetView.swift
//  NetNewsWire iOS Widget Extension
//
//  Created by Stuart Breckenridge on 08/01/2026.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import SwiftUI
import WidgetKit

struct LockScreenSummaryWidgetView: View {
	
	var entry: Provider.Entry
	
    var body: some View {
		VStack(alignment: .leading, spacing: 2) {
			HStack {
				unreadImage
				Text("label.text.unread", comment: "Unread")
				Spacer()
				Text(verbatim: entry.widgetData.currentUnreadCount.formatted())
			}
			HStack {
				todayImage
				Text("label.text.today", comment: "Today")
				Spacer()
				Text(verbatim: entry.widgetData.currentTodayCount.formatted())
			}
			HStack {
				starredImage
				Text("label.text.starred", comment: "Starred")
				Spacer()
				Text(verbatim: entry.widgetData.currentStarredCount.formatted())
			}
		}
		.font(.caption)
		.padding(2)
    }
	
	var starredImage: some View {
		Image(systemName: "star.fill")
			.resizable()
			.frame(width: WidgetLayout.titleImageSize, height: WidgetLayout.titleImageSize, alignment: .top)
			.cornerRadius(4)
			.foregroundColor(.yellow)
	}
	
	var unreadImage: some View {
		Image(systemName: "largecircle.fill.circle")
			.resizable()
			.frame(width: WidgetLayout.titleImageSize, height: WidgetLayout.titleImageSize, alignment: .top)
			.foregroundColor(.accentColor)
	}
	
	var todayImage: some View {
		Image(systemName: "sun.max.fill")
			.resizable()
			.frame(width: WidgetLayout.titleImageSize, height: WidgetLayout.titleImageSize, alignment: .top)
			.cornerRadius(4)
			.foregroundColor(.orange)
	}
	
	
}
