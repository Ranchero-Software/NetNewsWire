//
//  TimelineContextMenu.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 7/17/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct TimelineContextMenu: View {
	
	@EnvironmentObject private var timelineModel: TimelineModel
	var timelineItem: TimelineItem

    @ViewBuilder var body: some View {
		
		if timelineModel.canMarkIndicatedArticlesAsRead(timelineItem.article) {
			Button {
				timelineModel.markIndicatedArticlesAsRead(timelineItem.article)
			} label: {
				Text("Mark as Read")
				#if os(iOS)
				AppAssets.readOpenImage
				#endif
			}
		}
		
		if timelineModel.canMarkIndicatedArticlesAsUnread(timelineItem.article) {
			Button {
				timelineModel.markIndicatedArticlesAsUnread(timelineItem.article)
			} label: {
				Text("Mark as Unread")
				#if os(iOS)
				AppAssets.readClosedImage
				#endif
			}
		}
		
		if timelineModel.canMarkIndicatedArticlesAsStarred(timelineItem.article) {
			Button {
				timelineModel.markIndicatedArticlesAsStarred(timelineItem.article)
			} label: {
				Text("Mark as Starred")
				#if os(iOS)
				AppAssets.starClosedImage
				#endif
			}
		}
		
		if timelineModel.canMarkIndicatedArticlesAsUnstarred(timelineItem.article) {
			Button {
				timelineModel.markIndicatedArticlesAsUnstarred(timelineItem.article)
			} label: {
				Text("Mark as Unstarred")
				#if os(iOS)
				AppAssets.starOpenImage
				#endif
			}
		}
		
		if timelineModel.canMarkAboveAsRead(timelineItem.article) {
			Button {
				timelineModel.markAboveAsRead(timelineItem.article)
			} label: {
				Text("Mark Above as Read")
				#if os(iOS)
				AppAssets.markAboveAsReadImage
				#endif
			}
		}
		
		if timelineModel.canMarkBelowAsRead(timelineItem.article) {
			Button {
				timelineModel.markBelowAsRead(timelineItem.article)
			} label: {
				Text("Mark Below As Read")
				#if os(iOS)
				AppAssets.markBelowAsReadImage
				#endif
			}
		}
		
		if let feed = timelineItem.article.webFeed, timelineModel.canMarkAllAsReadInFeed(feed) {
			Divider()
			Button {
				timelineModel.markAllAsReadInFeed(feed)
			} label: {
				Text("Mark All as Read in “\(feed.nameForDisplay)”")
				#if os(iOS)
				AppAssets.markAllAsReadImage
				#endif
			}
		}

		if timelineModel.canOpenIndicatedArticleInBrowser(timelineItem.article) {
			Divider()
			Button {
				timelineModel.openIndicatedArticleInBrowser(timelineItem.article)
			} label: {
				Text("Open in Browser")
				#if os(iOS)
				AppAssets.openInBrowserImage
				#endif
			}
		}
		
	}
}
