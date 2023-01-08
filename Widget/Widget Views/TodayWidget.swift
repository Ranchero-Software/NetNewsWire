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
	@Environment(\.sizeCategory) var sizeCategory: ContentSizeCategory
	
	var entry: Provider.Entry
	
	var body: some View {
		if entry.widgetData.todayArticles.count == 0 {
			inboxZero
				.widgetURL(WidgetDeepLink.today.url)
		}
		else {
			GeometryReader { metrics in
				HStack {
					VStack {
						todayImage
							.padding(.vertical, 12)
							.padding(.leading, 8)
						Spacer()
					
					}
				}
				.frame(width: metrics.size.width * 0.15)
				
				Spacer()
				
				VStack(alignment:.leading, spacing: 0) {
					ForEach(0..<maxCount(), id: \.self, content: { i in
						if i != 0 {
							Divider()
							ArticleItemView(article: entry.widgetData.todayArticles[i],
											deepLink: WidgetDeepLink.todayArticle(id: entry.widgetData.todayArticles[i].id).url)
								.padding(.top, 8)
								.padding(.bottom, 4)
						} else {
							ArticleItemView(article: entry.widgetData.todayArticles[i],
											deepLink: WidgetDeepLink.todayArticle(id: entry.widgetData.todayArticles[i].id).url)
								.padding(.bottom, 4)
						}
					})
					Spacer()
				}
				.padding(.leading, metrics.size.width * 0.175)
				.padding([.bottom, .trailing])
				.padding(.top, 12)
				.overlay(
					 VStack {
						Spacer()
						HStack {
							Spacer()
							if entry.widgetData.currentTodayCount - maxCount() > 0 {
								Text(String(format: NSLocalizedString("today.count.%lld", comment: "Number of today articles beyond what are currently displayed in the widget."), locale: .current, todayCount()))
									.font(.caption2)
									.bold()
									.foregroundColor(.secondary)
								
								
							}
						}
					}
					.padding(.horizontal)
					.padding(.bottom, 6)
				)
			
			}.widgetURL(WidgetDeepLink.today.url)
		}
	}
	
	var todayImage: some View {
		Image(systemName: "sun.max.fill")
			.resizable()
			.frame(width: 30, height: 30, alignment: .center)
			.cornerRadius(4)
			.foregroundColor(.orange)
	}
	
	func todayCount() -> Int {
		entry.widgetData.currentTodayCount - maxCount()
	}
	
	func maxCount() -> Int {
		var reduceAccessibilityCount: Int = 0
		if SizeCategories().isSizeCategoryLarge(category: sizeCategory) {
			reduceAccessibilityCount = 1
		}
		
		if family == .systemLarge {
			return entry.widgetData.todayArticles.count >= 7 ? (7 - reduceAccessibilityCount) : entry.widgetData.todayArticles.count
		}
		return entry.widgetData.todayArticles.count >= 3 ? (3 - reduceAccessibilityCount) : entry.widgetData.todayArticles.count
	}
	
	var inboxZero: some View {
		VStack(alignment: .center) {
			Spacer()
			Image(systemName: "sun.max.fill")
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(width: 30)
				.foregroundColor(.orange)
				

			Text("widget.title.today-no-items", comment: "Today")
				.font(.headline)
				.foregroundColor(.primary)
			
			Text("widget.description.today-no-items", comment: "There are no recent unread articles left to read.")
				.font(.caption)
				.foregroundColor(.gray)
			Spacer()
		}
		.multilineTextAlignment(.center)
		.padding()
	}
	
}
