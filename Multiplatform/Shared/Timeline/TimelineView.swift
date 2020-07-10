//
//  TimelineView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/30/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct TimelineView: View {
	
	@EnvironmentObject private var timelineModel: TimelineModel

	var body: some View {
		List(timelineModel.timelineItems) { timelineItem in
			ZStack {
				TimelineItemView(timelineItem: timelineItem)
					.onAppear {
						timelineModel.loadMoreTimelineItemsIfNecessary(timelineItem)
					}
				NavigationLink(destination: (ArticleContainerView(article: timelineItem.article))) {
					EmptyView()
				}.buttonStyle(PlainButtonStyle())
			}
		}
    }
	
//	var body: some View {
//		List(timelineModel.timelineItems) { timelineItem in
//			TimelineItemView(timelineItem: timelineItem)
//		}
//	}
	
}
