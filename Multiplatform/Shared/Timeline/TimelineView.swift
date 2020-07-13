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
	@State var navigate = false

	@ViewBuilder var body: some View {
		#if os(macOS)
		VStack {
			HStack {
				TimelineSortOrderView()
				Spacer()
				Button (action: {
					withAnimation {
						timelineModel.toggleReadFilter()
					}
				}, label: {
					if timelineModel.isReadFiltered ?? false {
						AppAssets.filterActiveImage
					} else {
						AppAssets.filterInactiveImage
					}
				})
				.hidden(timelineModel.isReadFiltered == nil)
				.padding(.top, 8).padding(.trailing)
				.buttonStyle(PlainButtonStyle())
				.help(timelineModel.isReadFiltered ?? false ? "Show Read Articles" : "Filter Read Articles")
			}
			ZStack {
				NavigationLink(destination: ArticleContainerView(articles: timelineModel.selectedArticles), isActive: $navigate) {
					EmptyView()
				}.hidden()
				List(timelineModel.timelineItems, selection: $timelineModel.selectedArticleIDs) { timelineItem in
					TimelineItemView(timelineItem: timelineItem)
				}
			}
			.onChange(of: timelineModel.selectedArticleIDs) { value in
				navigate = !timelineModel.selectedArticleIDs.isEmpty
			}
		}
		.navigationTitle(Text(verbatim: timelineModel.nameForDisplay))
		#else
		List(timelineModel.timelineItems) { timelineItem in
			ZStack {
				TimelineItemView(timelineItem: timelineItem)
				NavigationLink(destination: ArticleContainerView(articles: timelineModel.selectedArticles),
							   tag: timelineItem.article.articleID,
							   selection: $timelineModel.selectedArticleID) {
					EmptyView()
				}.buttonStyle(PlainButtonStyle())
			}
		}
		.navigationBarTitle(Text(verbatim: timelineModel.nameForDisplay), displayMode: .inline)
		#endif
    }

}
