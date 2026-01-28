//
//  StarredWidget.swift
//  NetNewsWire Widget Extension
//
//  Created by Stuart Breckenridge on 18/11/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import WidgetKit
import SwiftUI

struct StarredWidgetView: View {
	@Environment(\.widgetFamily) var family: WidgetFamily
	@Environment(\.sizeCategory) var sizeCategory: ContentSizeCategory

	var entry: Provider.Entry

	var body: some View {
		if entry.widgetData.starredArticles.count == 0 {
			inboxZero
				.widgetURL(WidgetDeepLink.starred.url)
		} else {
			VStack {
				HStack(alignment: .center) {
					starredImage
						.layoutPriority(1)
					Text("label.text.starred", comment: "Starred")
						.font(.caption2)
						.bold()
						.lineLimit(1)
						.minimumScaleFactor(0.8)
						.fixedSize(horizontal: false, vertical: true)
						.layoutPriority(1)
					Spacer()
						.layoutPriority(0)
					if entry.widgetData.totalStarredCount - maxCount() > 0 {
						Text(verbatim: entry.widgetData.totalStarredCount.formatted())
							.font(.caption2)
							.bold()
							.foregroundColor(.secondary)
							.lineLimit(1)
							.minimumScaleFactor(0.8)
							.fixedSize(horizontal: false, vertical: true)
					}
				}
				.widgetURL(WidgetDeepLink.starred.url)
				Divider()
				if entry.widgetData.starredArticles.count > 0 {
					ForEach(0..<maxCount(), id: \.self, content: { i in
						ArticleItemView(article: entry.widgetData.starredArticles[i],
										deepLink: WidgetDeepLink.starredArticle(id: entry.widgetData.starredArticles[i].id).url)
					})
				}
				Spacer()
			}
			.padding(.vertical, 2)
		}
	}

	var starredImage: some View {
		Image(systemName: "star.fill")
			.resizable()
			.frame(width: WidgetLayout.titleImageSize, height: WidgetLayout.titleImageSize, alignment: .top)
			.cornerRadius(4)
			.foregroundColor(.yellow)
	}

	func maxCount() -> Int {
		var reduceAccessibilityCount: Int = 0
		if SizeCategories().isSizeCategoryLarge(category: sizeCategory) {
			reduceAccessibilityCount = 1
		}

		if family == .systemLarge {
			return entry.widgetData.totalStarredCount >= 7 ? (7 - reduceAccessibilityCount) : entry.widgetData.totalStarredCount
		}
		return entry.widgetData.totalStarredCount >= 3 ? (3 - reduceAccessibilityCount) : entry.widgetData.totalStarredCount
	}

	var inboxZero: some View {
		VStack(alignment: .center) {
			Spacer()
			Image(systemName: "star.fill")
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(width: 30)
				.foregroundColor(.yellow)

			Text("label.text.starred", comment: "Starred")
				.font(.headline)
				.foregroundColor(.primary)

			Text("label.text.starred-no-articles", comment: "There are no starred articles.")
				.font(.caption)
				.foregroundColor(.gray)
			Spacer()
		}
		.multilineTextAlignment(.center)
		.padding()
	}
}
