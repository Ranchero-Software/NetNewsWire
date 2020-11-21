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
	
	var entry: Provider.Entry
	
	var body: some View {
		if entry.widgetData.currentUnreadCount == 0 {
			inboxZero
		}
		else {
			VStack(alignment: .leading) {
				HStack(alignment: .top, spacing: 8) {
					VStack {
						unreadImage
						Spacer()
						nnwImage
					}
					VStack(alignment:.leading, spacing: 2) {
						ForEach(0..<maxCount(), content: { i in
							ArticleItemView(article: entry.widgetData.unreadArticles[i],
											deepLink: WidgetDeepLink.unreadArticle(id: entry.widgetData.unreadArticles[i].id).url)
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
			.widgetURL(WidgetDeepLink.unread.url)
		}
	}
	
	var unreadImage: some View {
		Image(systemName: "largecircle.fill.circle")
			.resizable()
			.frame(width: 25, height: 25, alignment: .center)
			.cornerRadius(4)
			.foregroundColor(.accentColor)
	}
	
	var nnwImage: some View {
		Image("CornerIcon")
			.resizable()
			.frame(width: 25, height: 25, alignment: .center)
			.cornerRadius(4)
	}
	
	var countText: some View {
		var count = entry.widgetData.currentUnreadCount
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
			return entry.widgetData.unreadArticles.count > 8 ? 8 : entry.widgetData.unreadArticles.count
		}
		return entry.widgetData.unreadArticles.count > 3 ? 3 : entry.widgetData.unreadArticles.count
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
				
				Text(L10n.unreadWidgetNoItems)
					.font(.caption2)
					.foregroundColor(.gray)
			}
		}.padding()
	}
	
}

