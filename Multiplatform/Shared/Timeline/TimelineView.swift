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
	@State var navigate = true

	@ViewBuilder var body: some View {
		GeometryReader { proxy in
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
					NavigationLink(destination: ArticleContainerView(), isActive: $navigate) {
						EmptyView()
					}.hidden()
					List(timelineModel.timelineItems, selection: $timelineModel.selectedArticleIDs) { timelineItem in
						let selected = timelineModel.selectedArticleIDs.contains(timelineItem.article.articleID)
						TimelineItemView(selected: selected, width: proxy.size.width, timelineItem: timelineItem)
					}
				}
			}
			.navigationTitle(Text(verbatim: timelineModel.nameForDisplay))
			#else
			List(timelineModel.timelineItems) { timelineItem in
				ZStack {
					let selected = timelineModel.selectedArticleID == timelineItem.article.articleID
					TimelineItemView(selected: selected, width: proxy.size.width, timelineItem: timelineItem)
					NavigationLink(destination: ArticleContainerView(),
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

}
