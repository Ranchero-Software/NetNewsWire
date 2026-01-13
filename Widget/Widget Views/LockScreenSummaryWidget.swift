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
				Text(verbatim: entry.widgetData.totalUnreadCount.formatted())
					.frame(maxWidth: .infinity, alignment: .trailing)
			}
			HStack(alignment: .center) {
				todayImage
				Text("label.text.today", comment: "Today")
				Spacer()
				Text(verbatim: entry.widgetData.totalTodayCount.formatted())
					.frame(maxWidth: .infinity, alignment: .trailing)
			}
			HStack(alignment: .center) {
				starredImage
				Text("label.text.starred", comment: "Starred")
				Spacer()
				Text(verbatim: entry.widgetData.totalStarredCount.formatted())
					.frame(maxWidth: .infinity, alignment: .trailing)
			}
		}
		.font(.subheadline)
    }

	var starredImage: some View {
		Image(systemName: "star.fill")
			.resizable()
			.frame(width: 14, height: 14)
	}

	var unreadImage: some View {
		Image(systemName: "largecircle.fill.circle")
			.resizable()
			.frame(width: 14, height: 14)
	}

	var todayImage: some View {
		Image(systemName: "sun.max.fill")
			.resizable()
			.frame(width: 14, height: 14)
	}

}
