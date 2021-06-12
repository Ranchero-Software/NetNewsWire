//
//  TimelineView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/30/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct TimelineView: View {
	
	@Binding var timelineItems: TimelineItems
	@Binding var isReadFiltered: Bool?

	@EnvironmentObject private var timelineModel: TimelineModel

	@State private var timelineItemFrames = [String: CGRect]()
	@State private var searchText: String = ""
	
	var body: some View {
		GeometryReader { geometryReaderProxy in
			#if os(macOS)
			ScrollViewReader { scrollViewProxy in
				List(timelineItems.items, selection: $timelineModel.selectedTimelineItemIDs) { timelineItem in
					let selected = timelineModel.selectedTimelineItemIDs.contains(timelineItem.article.articleID)
					TimelineItemView(selected: selected, width: geometryReaderProxy.size.width, timelineItem: timelineItem)
						.background(TimelineItemFramePreferenceView(timelineItem: timelineItem))
				}
				.id(timelineModel.listID)
				.onPreferenceChange(TimelineItemFramePreferenceKey.self) { preferences in
					for pref in preferences {
						timelineItemFrames[pref.articleID] = pref.frame
					}
				}
				.onChange(of: timelineModel.selectedTimelineItemIDs) { selectedArticleIDs in
					let proxyFrame = geometryReaderProxy.frame(in: .global)
					for articleID in selectedArticleIDs {
						if let itemFrame = timelineItemFrames[articleID] {
							if itemFrame.minY < proxyFrame.minY + 3 || itemFrame.maxY > proxyFrame.maxY - 35 {
								withAnimation {
									scrollViewProxy.scrollTo(articleID, anchor: .center)
								}
							}
						}
					}
				}
			}
			.navigationTitle(Text(verbatim: timelineModel.nameForDisplay))
			.navigationSubtitle(Text(verbatim: "\(timelineModel.unreadCount) unread"))
			.searchable(Text("Search"), text: $searchText, placement: .toolbar)
			#else
			ScrollViewReader { scrollViewProxy in
				List(timelineItems.items) { timelineItem in
					ZStack {
						let selected = timelineModel.selectedTimelineItemID == timelineItem.article.articleID
						TimelineItemView(selected: selected, width: geometryReaderProxy.size.width, timelineItem: timelineItem)
							.background(TimelineItemFramePreferenceView(timelineItem: timelineItem))
						NavigationLink(destination: ArticleContainerView(),
									   tag: timelineItem.article.articleID,
									   selection: $timelineModel.selectedTimelineItemID) {
							EmptyView()
						}.buttonStyle(.plain)
					}
				}
				.id(timelineModel.listID)
				.onPreferenceChange(TimelineItemFramePreferenceKey.self) { preferences in
					for pref in preferences {
						timelineItemFrames[pref.articleID] = pref.frame
					}
				}
				.onChange(of: timelineModel.selectedTimelineItemID) { selectedArticleID in
					let proxyFrame = geometryReaderProxy.frame(in: .global)
					if let articleID = selectedArticleID, let itemFrame = timelineItemFrames[articleID] {
						if itemFrame.minY < proxyFrame.minY + 3 || itemFrame.maxY > proxyFrame.maxY - 3 {
							withAnimation {
								scrollViewProxy.scrollTo(articleID, anchor: .center)
							}
						}
					}
				}
			}
			.navigationBarTitle(Text(verbatim: timelineModel.nameForDisplay), displayMode: .inline)
			#endif
		}
    }

}

struct TimelineItemFramePreferenceKey: PreferenceKey {
	typealias Value = [TimelineItemFramePreference]

	static var defaultValue: [TimelineItemFramePreference] = []
	
	static func reduce(value: inout [TimelineItemFramePreference], nextValue: () -> [TimelineItemFramePreference]) {
		value.append(contentsOf: nextValue())
	}
}

struct TimelineItemFramePreference: Equatable {
	let articleID: String
	let frame: CGRect
}

struct TimelineItemFramePreferenceView: View {
	let timelineItem: TimelineItem
	
	var body: some View {
		GeometryReader { proxy in
			Rectangle()
				.fill(Color.clear)
				.preference(key: TimelineItemFramePreferenceKey.self,
							value: [TimelineItemFramePreference(articleID: timelineItem.article.articleID, frame: proxy.frame(in: .global))])
		}
	}
}
