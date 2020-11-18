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
			VStack(alignment: .leading) {
				HStack(alignment: .top, spacing: 8) {
					VStack {
						todayImage
						Spacer()
						nnwImage
					}
					VStack(alignment:.leading, spacing: 4) {
						ForEach(0..<maxCount(), content: { i in
							ArticleItemView(article: entry.widgetData.todayArticles[i],
											deepLink: WidgetDeepLink.todayArticle(id: entry.widgetData.todayArticles[i].id).url)
						})
						Spacer()
						HStack {
							Spacer()
							countText
						}
					}
				}
			}
			.padding()
			.widgetURL(WidgetDeepLink.today.url)
			
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
	
	var countText: some View {
		var count = entry.widgetData.currentTodayCount
		if family == .systemLarge {
			count = count - 8
		} else {
			count = count - 3
		}
		if count < 0 { count = 0 }
		let formatString = NSLocalizedString("TodayCount",
											 comment: "Today Count Format")
		let str = String.localizedStringWithFormat(formatString, UInt(count))
		return Text(str)
			.font(.caption2)
			.bold()
			.foregroundColor(.accentColor)
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
			Text("#TodayZero")
				.italic()
				.font(Font.system(.subheadline, design: .serif))
			
			Spacer()
			HStack {
				Image("CornerIcon")
					.resizable()
					.frame(width: 15, height: 15, alignment: .center)
					.cornerRadius(4)
				
				Text("There are no recent articles to read.")
					.font(.caption2)
					.foregroundColor(.gray)
			}
		}.padding()
	}
	
}
