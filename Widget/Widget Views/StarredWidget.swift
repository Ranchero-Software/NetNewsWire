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
	
	var entry: Provider.Entry
	
	var body: some View {
		if entry.widgetData.starredArticles.count == 0 {
			inboxZero
		}
		else {
			GeometryReader { metrics in
				HStack(alignment: .top, spacing: 4) {
					VStack(alignment: .leading) {
						starredImage
						Spacer()
						Text(L10n.localizedCount(entry.widgetData.currentStarredCount)).bold().font(Font.system(.footnote, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1)
						Text(L10n.starred.lowercased()).bold().font(Font.system(.footnote).lowercaseSmallCaps()).minimumScaleFactor(0.5).lineLimit(1)
					}
					.frame(width: metrics.size.width * 0.15)
					.padding(.trailing, 4)
					
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
					}.padding(.leading, 4)
				}.padding()
			}
			
		}
	}
	
	var starredImage: some View {
		Image(systemName: "star.fill")
			.resizable()
			.frame(width: 25, height: 25, alignment: .center)
			.cornerRadius(4)
			.foregroundColor(.yellow)
	}
	
	var nnwImage: some View {
		Image("CornerIcon")
			.resizable()
			.frame(width: 25, height: 25, alignment: .center)
			.cornerRadius(4)
	}
	
	func maxCount() -> Int {
		if family == .systemLarge {
			return entry.widgetData.currentStarredCount > 7 ? 7 : entry.widgetData.currentStarredCount
		}
		return entry.widgetData.currentStarredCount > 3 ? 3 : entry.widgetData.currentStarredCount
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
				
				Text(L10n.starredWidgetNoItems)
					.font(.caption2)
					.foregroundColor(.gray)
			}
		}.padding()
	}
	
}
