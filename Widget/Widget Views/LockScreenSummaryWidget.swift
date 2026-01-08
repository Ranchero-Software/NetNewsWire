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
			HStack(alignment: .center) {
				unreadImage
				Text("label.text.unread", comment: "Unread")
				Spacer()
				Text(verbatim: entry.widgetData.currentUnreadCount.formatted())
					.frame(maxWidth: .infinity, alignment: .trailing)
			}
			HStack(alignment: .center) {
				todayImage
				Text("label.text.today", comment: "Today")
				Spacer()
				Text(verbatim: entry.widgetData.currentTodayCount.formatted())
					.frame(maxWidth: .infinity, alignment: .trailing)
			}
			HStack(alignment: .center) {
				starredImage
				Text("label.text.starred", comment: "Starred")
				Spacer()
				Text(verbatim: entry.widgetData.currentStarredCount.formatted())
					.frame(maxWidth: .infinity, alignment: .trailing)
			}
		}
		.font(.caption)
    }
	
	var starredImage: some View {
		Image(systemName: "star.fill")
			.frame(width: 14, height: 14)
	}
	
	var unreadImage: some View {
		Image(systemName: "largecircle.fill.circle")
			.frame(width: 14, height: 14)
	}
	
	var todayImage: some View {
		Image(systemName: "sun.max.fill")
			.frame(width: 14, height: 14)
	}
	
}
