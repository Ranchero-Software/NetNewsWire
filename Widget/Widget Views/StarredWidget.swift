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
			GeometryReader { metrics in
				starredImage
					.frame(width: WidgetLayout.titleImageSize, alignment: .leading)
				VStack(alignment: .leading, spacing: 0) {
					ForEach(0..<maxCount(), id: \.self, content: { i in
						if i != 0 {
							Divider()
							ArticleItemView(article: entry.widgetData.starredArticles[i],
											deepLink: WidgetDeepLink.starredArticle(id: entry.widgetData.starredArticles[i].id).url)
							.padding(.top, WidgetLayout.articleItemViewPaddingTop)
							.padding(.bottom, WidgetLayout.articleItemViewPaddingBottom)
						} else {
							ArticleItemView(article: entry.widgetData.starredArticles[i],
											deepLink: WidgetDeepLink.starredArticle(id: entry.widgetData.starredArticles[i].id).url)
							.padding(.bottom, WidgetLayout.articleItemViewPaddingBottom)
						}
					})
					Spacer()
				}
				.padding(.leading, WidgetLayout.leftSideWidth)
				.padding([.bottom, .trailing])
				.overlay(
					VStack {
						Spacer()
						HStack {
							Spacer()
							if entry.widgetData.currentStarredCount - maxCount() > 0 {
								Text(L10n.starredCount(entry.widgetData.currentStarredCount - maxCount()))
									.font(.caption2)
									.bold()
									.foregroundColor(.secondary)
							}
						}
					}
						.padding(.horizontal)
				)

			}
			.widgetURL(WidgetDeepLink.starred.url)
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

		let starredCount = entry.widgetData.starredArticles.count
		if family == .systemLarge {
			return starredCount >= 7 ? (7 - reduceAccessibilityCount) : starredCount
		}
		return starredCount >= 3 ? (3 - reduceAccessibilityCount) : starredCount
	}

	var inboxZero: some View {
		VStack(alignment: .center) {
			Spacer()
			Image(systemName: "star.fill")
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(width: 30)
				.foregroundColor(.yellow)


			Text(L10n.starredWidgetNoItemsTitle)
				.font(.headline)
				.foregroundColor(.primary)

			Text(L10n.starredWidgetNoItems)
				.font(.caption)
				.foregroundColor(.gray)
			Spacer()
		}
		.multilineTextAlignment(.center)
		.padding()
	}

}
