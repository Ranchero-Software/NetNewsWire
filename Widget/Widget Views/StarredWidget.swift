//
//  StarredWidget.swift
//  NetNewsWire Widget Extension
//
//  Created by Stuart Breckenridge on 18/11/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import WidgetKit
import SwiftUI

struct StarredWidgetView : View {
	
	@Environment(\.widgetFamily) var family: WidgetFamily
	@Environment(\.sizeCategory) var sizeCategory: ContentSizeCategory
	
	var entry: Provider.Entry
	
	var body: some View {
		if entry.widgetData.starredArticles.count == 0 {
			inboxZero
				.widgetURL(WidgetDeepLink.starred.url)
		}
		else {
			GeometryReader { metrics in
				HStack {
					VStack {
						starredImage
							.padding(.vertical, 12)
							.padding(.leading, 8)
						Spacer()
					
					}
				}
				.frame(width: metrics.size.width * 0.15)
				
				Spacer()
				
				VStack(alignment:.leading, spacing: 0) {
					ForEach(0..<maxCount(), content: { i in
						if i != 0 {
							Divider()
							ArticleItemView(article: entry.widgetData.starredArticles[i],
											deepLink: WidgetDeepLink.starredArticle(id: entry.widgetData.starredArticles[i].id).url)
								.padding(.top, 8)
								.padding(.bottom, 4)
						} else {
							ArticleItemView(article: entry.widgetData.starredArticles[i],
											deepLink: WidgetDeepLink.starredArticle(id: entry.widgetData.starredArticles[i].id).url)
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
							if entry.widgetData.currentStarredCount - maxCount() > 0 {
								Text(L10n.starredCount(entry.widgetData.currentStarredCount - maxCount()))
									.font(.caption2)
									.bold()
									.foregroundColor(.secondary)
							}
						}
					}
					.padding(.horizontal)
					.padding(.bottom, 6)
				)
			
			}.widgetURL(WidgetDeepLink.starred.url)
			
		}
	}
	
	var starredImage: some View {
		Image(systemName: "star.fill")
			.resizable()
			.frame(width: 30, height: 30, alignment: .center)
			.cornerRadius(4)
			.foregroundColor(.yellow)
	}
	
	func maxCount() -> Int {
		var reduceAccessibilityCount: Int = 0
		if SizeCategories().isSizeCategoryLarge(category: sizeCategory) {
			reduceAccessibilityCount = 1
		}
		
		if family == .systemLarge {
			return entry.widgetData.currentStarredCount >= 7 ? (7 - reduceAccessibilityCount) : entry.widgetData.currentStarredCount
		}
		return entry.widgetData.currentStarredCount >= 3 ? (3 - reduceAccessibilityCount) : entry.widgetData.currentStarredCount
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
