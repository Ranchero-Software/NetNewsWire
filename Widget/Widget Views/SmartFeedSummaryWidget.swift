//
//  SmartFeedSummaryWidget.swift
//  NetNewsWire Widget Extension
//
//  Created by Stuart Breckenridge on 18/11/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import WidgetKit
import SwiftUI


struct SmartFeedSummaryWidgetView: View {
	
	@Environment(\.widgetFamily) var family: WidgetFamily
	
	var entry: Provider.Entry
	
	var body: some View {
		switch family {
		case .systemSmall:
			smallWidget
		case .systemMedium:
			smallWidget
		case .systemLarge:
			smallWidget
		@unknown default:
			smallWidget
		}
	}
	
	@ViewBuilder
	var smallWidget: some View {
		VStack(alignment: .leading) {
			Link(destination: WidgetDeepLink.today.url, label: {
				HStack {
					todayImage
					Text(formattedCount(entry.widgetData.currentTodayCount) + " Today").font(.caption)
					Spacer()
				}
			})
			
			Link(destination: WidgetDeepLink.unread.url, label: {
				HStack {
					unreadImage
					Text(formattedCount(entry.widgetData.currentUnreadCount) + " Unread").font(.caption)
					Spacer()
				}
			})
			
			Link(destination: WidgetDeepLink.starred.url, label: {
				HStack {
					starredImage
					Text(formattedCount(entry.widgetData.currentStarredCount) + " Starred").font(.caption)
					Spacer()
				}
			})
			Spacer()
			HStack {
				Spacer()
				Text(L10n.smartfeedTitle).bold().textCase(.uppercase).font(.caption2)
				Spacer()
			}
		}.padding()
	}
	
	func formattedCount(_ count: Int) -> String {
		let formatter = NumberFormatter()
		formatter.locale = Locale.current
		formatter.numberStyle = .decimal
		return formatter.string(from: NSNumber(value: count))!
	}
	
	var unreadImage: some View {
		Image(systemName: "largecircle.fill.circle")
			.resizable()
			.frame(width: 20, height: 20, alignment: .center)
			.foregroundColor(.accentColor)
	}
	
	var nnwImage: some View {
		Image("CornerIcon")
			.resizable()
			.frame(width: 20, height: 20, alignment: .center)
			.cornerRadius(4)
	}
	
	var starredImage: some View {
		Image(systemName: "star.fill")
			.resizable()
			.frame(width: 20, height: 20, alignment: .center)
			.foregroundColor(.yellow)
	}
	
	var todayImage: some View {
		Image(systemName: "sun.max.fill")
			.resizable()
			.frame(width: 20, height: 20, alignment: .center)
			.foregroundColor(.orange)
	}
	
}
