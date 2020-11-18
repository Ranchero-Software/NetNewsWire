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
					VStack(alignment:.leading, spacing: 4) {
						ForEach(0..<maxCount(), content: { i in
							ArticleItemView(article: entry.widgetData.starredArticles[i],
											deepLink: WidgetDeepLink.starredArticle(id: entry.widgetData.starredArticles[i].id).url)
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
	
	var unreadCountText: some View {
		if entry.widgetData.currentStarredCount > 3 {
			let count = entry.widgetData.currentStarredCount - 3
			let formatter = NumberFormatter()
			formatter.locale = Locale.current
			formatter.numberStyle = .decimal
			let formattedCount = formatter.string(from: NSNumber(value: count))
			var str = ""
			if count == 1 {
				str = "+ \(formattedCount!) more starred article..."
			} else {
				str = "+ \(formattedCount!) more starred articles..."
			}
			return Text(str)
				.font(.caption2)
				.bold()
				.foregroundColor(.accentColor)
		} else {
			let formatter = NumberFormatter()
			formatter.locale = Locale.current
			formatter.numberStyle = .decimal
			let formattedCount = formatter.string(from: NSNumber(value: entry.widgetData.currentStarredCount))
			var str = ""
			if entry.widgetData.currentStarredCount == 1 {
				str = "\(formattedCount!) starred article"
			} else {
				str = "\(formattedCount!) starred articles"
			}
			return Text(str)
				.font(.caption2)
				.bold()
				.foregroundColor(.accentColor)
		}
	}
	
	func maxCount() -> Int {
		return entry.widgetData.starredArticles.count > 3 ? 3 : entry.widgetData.starredArticles.count
	}
	
	var inboxZero: some View {
		VStack {
			Spacer()
			Text("#StarredZero")
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
				
				Text("You've not starred any artices.")
					.font(.caption2)
					.foregroundColor(.gray)
			}.padding(.bottom, 8)
		}.padding()
	}
	
}
