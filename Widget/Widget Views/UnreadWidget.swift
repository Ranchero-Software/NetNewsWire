//
//  UnreadWidget.swift
//  NetNewsWire Widget Extension
//
//  Created by Stuart Breckenridge on 18/11/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import WidgetKit
import SwiftUI

struct UnreadWidgetView : View {
	
	@Environment(\.widgetFamily) var family: WidgetFamily
	@Environment(\.sizeCategory) var sizeCategory: ContentSizeCategory
	
	var entry: Provider.Entry
	
	var body: some View {
		if entry.widgetData.currentUnreadCount == 0 {
			inboxZero
				.widgetURL(WidgetDeepLink.unread.url)
		}
		else {
			GeometryReader { metrics in
				HStack(alignment: .top, spacing: 4) {
					VStack(alignment: .leading, spacing: -4) {
						unreadImage
						Spacer()
						Text(L10n.localizedCount(entry.widgetData.currentUnreadCount)).bold().font(.callout).minimumScaleFactor(0.5).lineLimit(1)
						Text(L10n.unread.lowercased()).bold().font(Font.system(.footnote).lowercaseSmallCaps()).minimumScaleFactor(0.5).lineLimit(1)
					}
					.frame(width: metrics.size.width * 0.15)
					.padding(.trailing, 4)
					
					VStack(alignment:.leading, spacing: 0) {
						ForEach(0..<maxCount(), content: { i in
							if i != 0 {
								Divider()
								ArticleItemView(article: entry.widgetData.unreadArticles[i],
												deepLink: WidgetDeepLink.unreadArticle(id: entry.widgetData.unreadArticles[i].id).url)
									.padding(.top, 8)
									.padding(.bottom, 4)
							} else {
								ArticleItemView(article: entry.widgetData.unreadArticles[i],
												deepLink: WidgetDeepLink.unreadArticle(id: entry.widgetData.unreadArticles[i].id).url)
									.padding(.bottom, 4)
							}
							
						})
						Spacer()
					}.padding(.leading, 4)
				}.padding()
			}.widgetURL(WidgetDeepLink.unread.url)
		}
	}
	
	var unreadImage: some View {
		Image(systemName: "largecircle.fill.circle")
			.resizable()
			.frame(width: 30, height: 30, alignment: .center)
			.cornerRadius(4)
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

			Text(L10n.unreadWidgetNoItemsTitle)
				.font(.headline)
				.foregroundColor(.primary)
			
			Text(L10n.unreadWidgetNoItems)
				.font(.caption)
				.foregroundColor(.gray)
			Spacer()
		}
		.multilineTextAlignment(.center)
		.padding()
	}
	
}

