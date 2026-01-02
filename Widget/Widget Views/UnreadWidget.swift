//
//  UnreadWidget.swift
//  NetNewsWire Widget Extension
//
//  Created by Stuart Breckenridge on 18/11/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import WidgetKit
import SwiftUI

struct UnreadWidgetView: View {
	@Environment(\.widgetFamily) var family: WidgetFamily
	@Environment(\.sizeCategory) var sizeCategory: ContentSizeCategory

	var entry: Provider.Entry

	var body: some View {
		if entry.widgetData.currentUnreadCount == 0 {
			inboxZero
				.widgetURL(WidgetDeepLink.unread.url)
		}
		else {
			VStack {
				Spacer()
				HStack {
					unreadImage
						.layoutPriority(1)
					Text("label.text.unread", comment: "Unread")
						.font(.caption2)
						.bold()
						.lineLimit(1)
						.minimumScaleFactor(0.8)
						.fixedSize(horizontal: false, vertical: true)
						.layoutPriority(1)
					Spacer()
						.layoutPriority(0)
					if entry.widgetData.currentUnreadCount - maxCount() > 0 {
						Text(verbatim: entry.widgetData.currentUnreadCount.formatted())
							.font(.caption2)
							.bold()
							.foregroundColor(.secondary)
							.lineLimit(1)
							.minimumScaleFactor(0.8)
							.fixedSize(horizontal: false, vertical: true)
					}
				}
				.widgetURL(WidgetDeepLink.unread.url)
				Divider()
				if entry.widgetData.unreadArticles.count > 0 {
					ForEach(0..<maxCount(), id: \.self, content: { i in
						if i != 0 {
							Divider()
							ArticleItemView(article: entry.widgetData.unreadArticles[i],
											deepLink: WidgetDeepLink.unreadArticle(id: entry.widgetData.unreadArticles[i].id).url)
						} else {
							ArticleItemView(article: entry.widgetData.unreadArticles[i],
											deepLink: WidgetDeepLink.unreadArticle(id: entry.widgetData.unreadArticles[i].id).url)
						}
					})
				}
				Spacer()
			}
			.padding(.vertical, 2)
		}
	}
			
	var unreadImage: some View {
		Image(systemName: "largecircle.fill.circle")
			.resizable()
			.frame(width: WidgetLayout.titleImageSize, height: WidgetLayout.titleImageSize, alignment: .top)
			.foregroundColor(.accentColor)
	}

	func maxCount() -> Int {
		var reduceAccessibilityCount: Int = 0
		if SizeCategories().isSizeCategoryLarge(category: sizeCategory) {
			reduceAccessibilityCount = 1
		}

		if family == .systemLarge {
			return entry.widgetData.unreadArticles.count >= 7 ? (7 - reduceAccessibilityCount) : entry.widgetData.unreadArticles.count
		}
		return entry.widgetData.unreadArticles.count >= 3 ? (3 - reduceAccessibilityCount) : entry.widgetData.unreadArticles.count
	}

	var inboxZero: some View {
		VStack(alignment: .center) {
			Spacer()
			Image(systemName: "largecircle.fill.circle")
				.resizable()
				.aspectRatio(contentMode: .fit)
				.foregroundColor(.accentColor)
				.frame(width: 30)

			Text("label.text.unread", comment: "Unread")
				.font(.headline)
				.foregroundColor(.primary)

			Text("label.text.unread-no-articles", comment: "There are no unread articles.")
				.font(.caption)
				.foregroundColor(.gray)
			Spacer()
		}
		.multilineTextAlignment(.center)
		.padding()
	}
}
