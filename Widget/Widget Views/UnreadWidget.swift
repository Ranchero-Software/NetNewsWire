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
		switch family {
		case .systemSmall:
			mediumWidget
		case .systemMedium:
			mediumWidget
		case .systemLarge:
			mediumWidget
		@unknown default:
			mediumWidget
		}
	}
	
	@ViewBuilder
	var mediumWidget: some View {
		if entry.widgetData.unreadArticles.count == 0 {
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
					VStack(alignment:.leading, spacing: 4) {
						ForEach(0..<maxCount(), content: { i in
							ArticleItemView(article: entry.widgetData.unreadArticles[i],
											deepLink: WidgetDeepLink.unreadArticle(id: entry.widgetData.unreadArticles[i].id).url)
						})
						Spacer()
						HStack {
							Spacer()
							unreadCountText
						}
					}
				}
			}
			.padding()
			.widgetURL(URL(string: "nnw-widget://showunread")!)
			
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
	
	var unreadCountText: some View {
		if entry.widgetData.currentUnreadCount > 3 {
			let count = entry.widgetData.currentUnreadCount - 3
			let formatter = NumberFormatter()
			formatter.locale = Locale.current
			formatter.numberStyle = .decimal
			let formattedCount = formatter.string(from: NSNumber(value: count))
			var str = ""
			if count == 1 {
				str = "+ \(formattedCount!) more unread article..."
			} else {
				str = "+ \(formattedCount!) more unread articles..."
			}
			return Text(str)
				.font(.caption2)
				.bold()
				.foregroundColor(.accentColor)
		} else {
			let formatter = NumberFormatter()
			formatter.locale = Locale.current
			formatter.numberStyle = .decimal
			let formattedCount = formatter.string(from: NSNumber(value: entry.widgetData.currentUnreadCount))
			var str = ""
			if entry.widgetData.currentUnreadCount == 1 {
				str = "\(formattedCount!) unread article"
			} else {
				str = "\(formattedCount!) unread articles"
			}
			return Text(str)
				.font(.caption2)
				.bold()
				.foregroundColor(.accentColor)
		}
	}
	
	func maxCount() -> Int {
		return entry.widgetData.unreadArticles.count > 3 ? 3 : entry.widgetData.unreadArticles.count
	}
	
	var inboxZero: some View {
		VStack {
			Spacer()
			Text("#UnreadZero")
				.italic()
				.font(Font.system(.subheadline, design: .serif))
				.fixedSize(horizontal: false, vertical: true)
				.padding(.bottom, 4)
			
			Spacer()
			HStack {
				Image("CornerIcon")
					.resizable()
					.frame(width: 15, height: 15, alignment: .center)
					.cornerRadius(4)
				
				Text("There's nothing to read right now.")
					.font(.caption2)
					.foregroundColor(.gray)
			}.padding(.bottom, 8)
		}.padding()
	}
	
}

