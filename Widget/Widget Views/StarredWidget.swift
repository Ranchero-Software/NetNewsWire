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
			VStack(alignment: .leading) {
				HStack(alignment: .top, spacing: 8) {
					VStack {
						starredImage
						Spacer()
						nnwImage
					}
					VStack(alignment:.leading, spacing: 2) {
						ForEach(0..<maxCount(), content: { i in
							ArticleItemView(article: entry.widgetData.starredArticles[i],
											deepLink: WidgetDeepLink.starredArticle(id: entry.widgetData.starredArticles[i].id).url)
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
			.widgetURL(WidgetDeepLink.starred.url)
			
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
	
	var countText: some View {
		var count = entry.widgetData.currentStarredCount
		if family == .systemLarge {
			count = count - 8
		} else {
			count = count - 3
		}
		if count < 0 { count = 0 }
		let str = L10n.unreadCount(count)
		return Text(str)
			.font(.caption2)
			.bold()
			.foregroundColor(.accentColor)
	}
	
	func maxCount() -> Int {
		if family == .systemLarge {
			return entry.widgetData.currentStarredCount > 8 ? 8 : entry.widgetData.currentStarredCount
		}
		return entry.widgetData.currentStarredCount > 3 ? 3 : entry.widgetData.currentStarredCount
	}
	
	var inboxZero: some View {
		VStack {
			Spacer()
			Text("#StarredZero")
				.italic()
				.font(Font.system(.subheadline, design: .serif))
			
			Spacer()
			HStack {
				Image("CornerIcon")
					.resizable()
					.frame(width: 15, height: 15, alignment: .center)
					.cornerRadius(4)
				
				Text("You've not starred any artices.")
					.font(.caption2)
					.foregroundColor(.gray)
			}
		}.padding()
	}
	
}
