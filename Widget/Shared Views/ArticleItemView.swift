//
//  ArticleItemView.swift
//  NetNewsWire Widget Extension
//
//  Created by Stuart Breckenridge on 18/11/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import RSWeb

struct ArticleItemView: View {
	
	var article: LatestArticle
	var deepLink: URL
	
	var body: some View {
		Link(destination: deepLink, label: {
			HStack(alignment: .top, spacing: nil, content: {
				// Feed Icon
				Image(uiImage: thumbnail(article.feedIcon))
					.resizable()
					.frame(width: 30, height: 30)
					.cornerRadius(4)
				
				// Title and Feed Name
				VStack(alignment: .leading) {
					Text(article.articleTitle ?? "Untitled")
						.font(.footnote)
						.bold()
						.lineLimit(1)
						.foregroundColor(.primary)
						.padding(.top, -3)
					
					HStack {
						Text(article.feedTitle)
							.font(.caption)
							.lineLimit(1)
							.foregroundColor(.secondary)
						Spacer()
						Text(pubDate(article.pubDate))
							.font(.caption)
							.lineLimit(1)
							.foregroundColor(.secondary)
					}
				}
			})
		})
	}
	
	func thumbnail(_ data: Data?) -> UIImage {
		if data == nil {
			return UIImage(systemName: "globe")!
		} else {
			return UIImage(data: data!)!
		}
	}
	
	func pubDate(_ dateString: String) -> String {
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
		guard let date = dateFormatter.date(from: dateString) else {
			return ""
		}
		
		let displayFormatter = DateFormatter()
		displayFormatter.dateStyle = .medium
		displayFormatter.timeStyle = .none
		
		return displayFormatter.string(from: date)
	}
}
