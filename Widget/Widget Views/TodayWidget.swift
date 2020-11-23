//
//  TodayWidget.swift
//  NetNewsWire Widget Extension
//
//  Created by Stuart Breckenridge on 18/11/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import WidgetKit
import SwiftUI

struct TodayWidgetView : View {
	
	@Environment(\.widgetFamily) var family: WidgetFamily
	
	var entry: Provider.Entry
	
	var body: some View {
		if entry.widgetData.todayArticles.count == 0 {
			inboxZero
		}
		else {
			GeometryReader { metrics in
				HStack(alignment: .top, spacing: 4) {
					VStack(alignment: .leading) {
						todayImage
						Spacer()
						Text(L10n.localizedCount(entry.widgetData.currentTodayCount)).bold().font(Font.system(.footnote, design: .rounded))
						Text(L10n.today.lowercased()).bold().font(Font.system(.footnote).lowercaseSmallCaps()).minimumScaleFactor(0.5).lineLimit(1)
					}
					.frame(width: metrics.size.width * 0.15)
					.padding(.trailing, 4)
					
					Divider()
					
					VStack(alignment:.leading, spacing: 0) {
						ForEach(0..<maxCount(), content: { i in
							if i != 0 {
								ArticleItemView(article: entry.widgetData.todayArticles[i],
												deepLink: WidgetDeepLink.todayArticle(id: entry.widgetData.todayArticles[i].id).url)
									.padding(.vertical, 4)
							} else {
								ArticleItemView(article: entry.widgetData.unreadArticles[i],
												deepLink: WidgetDeepLink.todayArticle(id: entry.widgetData.todayArticles[i].id).url)
									.padding(.bottom, 4)
							}
							
						})
						Spacer()
					}.padding(.leading, 4)
				}.padding()
			}
		}
	}
	
	var todayImage: some View {
		Image(systemName: "sun.max.fill")
			.resizable()
			.frame(width: 25, height: 25, alignment: .center)
			.cornerRadius(4)
			.foregroundColor(.orange)
	}
	
	var nnwImage: some View {
		Image("CornerIcon")
			.resizable()
			.frame(width: 25, height: 25, alignment: .center)
			.cornerRadius(4)
	}
	
	func maxCount() -> Int {
		if family == .systemLarge {
			return entry.widgetData.todayArticles.count > 8 ? 8 : entry.widgetData.todayArticles.count
		}
		return entry.widgetData.todayArticles.count > 3 ? 3 : entry.widgetData.todayArticles.count
	}
	
	var inboxZero: some View {
		VStack {
			Spacer()
			Image(systemName: "checkmark.circle")
				.foregroundColor(.accentColor)
				.font(.title)
			
			Spacer()
			HStack {
				Image("CornerIcon")
					.resizable()
					.frame(width: 15, height: 15, alignment: .center)
					.cornerRadius(4)
				
				Text(L10n.todayWidgetNoItems)
					.font(.caption2)
					.foregroundColor(.gray)
			}
		}.padding()
	}
	
}
