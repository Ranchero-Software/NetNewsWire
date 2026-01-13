//
//  TodayWidget.swift
//  NetNewsWire Widget Extension
//
//  Created by Stuart Breckenridge on 18/11/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import WidgetKit
import SwiftUI

struct TodayWidgetView: View {

	@Environment(\.widgetFamily) var family: WidgetFamily
	@Environment(\.sizeCategory) var sizeCategory: ContentSizeCategory

	var entry: Provider.Entry

	var body: some View {
		if entry.widgetData.totalTodayCount == 0 {
			inboxZero
				.widgetURL(WidgetDeepLink.today.url)
		} else {
			VStack {
				HStack(alignment: .center) {
					todayImage
						.layoutPriority(1)
					Text("label.text.today", comment: "Today")
						.font(.caption2)
						.bold()
						.lineLimit(1)
						.minimumScaleFactor(0.8)
						.fixedSize(horizontal: false, vertical: true)
						.layoutPriority(1)
					Spacer()
						.layoutPriority(0)
					if entry.widgetData.totalTodayCount > 0 {
						Text(verbatim: entry.widgetData.totalTodayUnreadCount > 0 ? "\(entry.widgetData.totalTodayCount.formatted()), \(entry.widgetData.totalTodayUnreadCount.formatted()) unread" : entry.widgetData.totalTodayCount.formatted())
							.font(.caption2)
							.bold()
							.foregroundColor(.secondary)
							.lineLimit(1)
							.minimumScaleFactor(0.8)
							.fixedSize(horizontal: false, vertical: true)
					}
				}
				.widgetURL(WidgetDeepLink.today.url)
				Divider()
				if entry.widgetData.todayArticles.count > 0 {
					ForEach(0..<maxCount(), id: \.self, content: { i in
						ArticleItemView(article: entry.widgetData.todayArticles[i],
										deepLink: WidgetDeepLink.todayArticle(id: entry.widgetData.todayArticles[i].id).url)
					})
				}
				Spacer()
			}
			.padding(.vertical, 2)
		}
	}

	var todayImage: some View {
		Image(systemName: "sun.max.fill")
			.resizable()
			.frame(width: WidgetLayout.titleImageSize, height: WidgetLayout.titleImageSize, alignment: .top)
			.cornerRadius(4)
			.foregroundColor(.orange)
	}

	func maxCount() -> Int {
		var reduceAccessibilityCount: Int = 0
		if SizeCategories().isSizeCategoryLarge(category: sizeCategory) {
			reduceAccessibilityCount = 1
		}

		if family == .systemLarge {
			return entry.widgetData.totalTodayCount >= 7 ? (7 - reduceAccessibilityCount) : entry.widgetData.totalTodayCount
		}
		return entry.widgetData.totalTodayCount >= 3 ? (3 - reduceAccessibilityCount) : entry.widgetData.totalTodayCount
	}

	var inboxZero: some View {
		VStack(alignment: .center) {
			Spacer()
			Image(systemName: "sun.max.fill")
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(width: 30)
				.foregroundColor(.orange)

			Text("label.text.today", comment: "Today")
				.font(.headline)
				.foregroundColor(.primary)

			Text("label.text.today-no-articles", comment: "There are no recent articles.")
				.font(.caption)
				.foregroundColor(.gray)
			Spacer()
		}
		.multilineTextAlignment(.center)
		.padding()
	}

}
