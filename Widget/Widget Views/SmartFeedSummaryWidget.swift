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
		rectangleWidget
			.widgetURL(WidgetDeepLink.icon.url)
	}
	
	@ViewBuilder
	var rectangleWidget: some View {
		VStack(alignment: .leading, spacing: 2) {
			HStack {
				todayImage
				Text(L10n.today).bold().font(.body)
				Spacer()
				Text(formattedCount(entry.widgetData.currentTodayCount)).bold()
				
			}
			
			HStack {
				unreadImage
				Text(L10n.unread).bold().font(.body)
				Spacer()
				Text(formattedCount(entry.widgetData.currentUnreadCount)).bold()
			}
			
			HStack {
				starredImage
				Text(L10n.starred).bold().font(.body)
				Spacer()
				Text(formattedCount(entry.widgetData.currentStarredCount)).bold()
			}
			
		}
		
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
			.frame(width: 12, height: 12, alignment: .center)
	}
	
	var nnwImage: some View {
		Image("CornerIcon")
			.resizable()
			.frame(width: 10, height: 10, alignment: .center)
			.cornerRadius(4)
	}
	
	var starredImage: some View {
		Image(systemName: "star.fill")
			.resizable()
			.frame(width: 12, height: 12, alignment: .center)
	}
	
	var todayImage: some View {
		Image(systemName: "sun.max.fill")
			.resizable()
			.frame(width: 12, height: 12, alignment: .center)
	}
	
}


@available(iOSApplicationExtension 16.0, *)
struct SmartFeedSummaryWidgetView_Previews: PreviewProvider {
	
	static var previews: some View {
		SmartFeedSummaryWidgetView(entry: Provider.Entry.init(date: Date(), widgetData: WidgetDataDecoder().sampleData()))
			.previewContext(WidgetPreviewContext(family: .accessoryRectangular))

	}
}
