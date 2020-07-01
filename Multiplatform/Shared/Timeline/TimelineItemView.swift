//
//  TimelineItemView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 7/1/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct TimelineItemView: View {
	
	@StateObject var articleIconImageLoader = ArticleIconImageLoader()
	var timelineItem: TimelineItem
	
    var body: some View {
		VStack {
			HStack(alignment: .top) {
				TimelineItemStatusView(status: timelineItem.status)
				if let image = articleIconImageLoader.image {
					IconImageView(iconImage: image)
						.frame(width: AppDefaults.timelineIconSize.size.width, height: AppDefaults.timelineIconSize.size.height, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
				}
				Text(verbatim: timelineItem.article.title ?? "N/A")
					.frame(maxWidth: .infinity, alignment: .leading)
			}
			Divider()
		}
		.onAppear {
			articleIconImageLoader.loadImage(for: timelineItem.article)
		}
    }
}

struct TimelineItemView_Previews: PreviewProvider {
    static var previews: some View {
		Group {
			TimelineItemView(timelineItem: TimelineItem(article: PreviewArticles.basicRead))
				.frame(maxWidth: 250)
			TimelineItemView(timelineItem: TimelineItem(article: PreviewArticles.basicUnread))
				.frame(maxWidth: 250)
			TimelineItemView(timelineItem: TimelineItem(article: PreviewArticles.basicStarred))
				.frame(maxWidth: 250)
		}
    }
}
