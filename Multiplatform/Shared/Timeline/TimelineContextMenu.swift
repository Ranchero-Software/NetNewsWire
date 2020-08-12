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

    var body: some View {
		
		if timelineModel.canMarkIndicatedArticlesAsRead(timelineItem) {
			Button {
				timelineModel.markIndicatedArticlesAsRead(timelineItem)
			} label: {
				Text("Mark as Read")
				#if os(iOS)
				AppAssets.readOpenImage
				#endif
			}
		}

		if timelineModel.canMarkIndicatedArticlesAsUnread(timelineItem) {
			Button {
				timelineModel.markIndicatedArticlesAsUnread(timelineItem)
			} label: {
				Text("Mark as Unread")
				#if os(iOS)
				AppAssets.readClosedImage
				#endif
			}
		}

		if timelineModel.canMarkIndicatedArticlesAsStarred(timelineItem) {
			Button {
				timelineModel.markIndicatedArticlesAsStarred(timelineItem)
			} label: {
				Text("Mark as Starred")
				#if os(iOS)
				AppAssets.starClosedImage
				#endif
			}
		}

		if timelineModel.canMarkIndicatedArticlesAsUnstarred(timelineItem) {
			Button {
				timelineModel.markIndicatedArticlesAsUnstarred(timelineItem)
			} label: {
				Text("Mark as Unstarred")
				#if os(iOS)
				AppAssets.starOpenImage
				#endif
			}
		}

		if timelineModel.canMarkAboveAsRead(timelineItem) {
			Button {
				timelineModel.markAboveAsRead(timelineItem)
			} label: {
				Text("Mark Above as Read")
				#if os(iOS)
				AppAssets.markAboveAsReadImage
				#endif
			}
		}

		if timelineModel.canMarkBelowAsRead(timelineItem) {
			Button {
				timelineModel.markBelowAsRead(timelineItem)
			} label: {
				Text("Mark Below As Read")
				#if os(iOS)
				AppAssets.markBelowAsReadImage
				#endif
			}
		}

		if timelineModel.canMarkAllAsReadInWebFeed(timelineItem) {
			Divider()
			Button {
				timelineModel.markAllAsReadInWebFeed(timelineItem)
			} label: {
				Text("Mark All as Read in “\(timelineItem.article.webFeed?.nameForDisplay ?? "")”")
				#if os(iOS)
				AppAssets.markAllAsReadImage
				#endif
			}
		}

		if timelineModel.canOpenIndicatedArticleInBrowser(timelineItem) {
			Divider()
			Button {
				timelineModel.openIndicatedArticleInBrowser(timelineItem)
			} label: {
				Text("Open in Browser")
				#if os(iOS)
				AppAssets.openInBrowserImage
				#endif
			}
		}
		
	}
}
