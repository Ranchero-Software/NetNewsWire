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

	@State private var navigate = false
	@State private var timelineItemFrames = [String: CGRect]()
	
	@ViewBuilder var body: some View {
		GeometryReader { geometryReaderProxy in
			#if os(macOS)
			VStack {
				HStack {
					TimelineSortOrderView()
					Spacer()
					Button (action: {
						if let filtered = isReadFiltered {
							timelineModel.changeReadFilterSubject.send(!filtered)
						}
					}, label: {
						if isReadFiltered ?? false {
							AppAssets.filterActiveImage
						} else {
							AppAssets.filterInactiveImage
						}
					})
					.hidden(isReadFiltered == nil)
					.padding(.top, 8).padding(.trailing)
					.buttonStyle(PlainButtonStyle())
					.help(isReadFiltered ?? false ? "Show Read Articles" : "Filter Read Articles")
				}
				ScrollView {
					ScrollViewReader { scrollViewProxy in
						LazyVStack {
							ForEach(timelineItems.items) { timelineItem in
								let selected = timelineModel.selectedTimelineItemIDs.contains(timelineItem.article.articleID)
								TimelineItemView(selected: selected, width: geometryReaderProxy.size.width, timelineItem: timelineItem)
									.background(TimelineItemBackgroundView(selected: selected, timelineItem: timelineItem))
									.onTapGesture {
										timelineModel.selectedTimelineItemIDs = Set([timelineItem.id])
									}
							}
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
					}
				}
			}
			.navigationTitle(Text(verbatim: timelineModel.nameForDisplay))
			#else
			ZStack {
				NavigationLink(destination: ArticleView(), isActive: $navigate) {
					EmptyView()
				}
				ScrollView {
					ScrollViewReader { scrollViewProxy in
						LazyVStack {
							ForEach(timelineItems.items) { timelineItem in
								let selected = timelineModel.selectedTimelineItemID == timelineItem.article.articleID
								TimelineItemView(selected: selected, width: geometryReaderProxy.size.width, timelineItem: timelineItem)
									.background(TimelineItemBackgroundView(selected: selected, timelineItem: timelineItem))
									.onTapGesture {
										timelineModel.selectedTimelineItemIDs = Set([timelineItem.id])
										navigate = true
									}
							}
						}
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

struct TimelineItemBackgroundView: View {
	
	let selected: Bool
	let timelineItem: TimelineItem
	
	var body: some View {
		GeometryReader { proxy in
			Rectangle()
				.fill(selected ? Color.accentColor : Color.clear)
				.cornerRadius(6)
				.preference(key: TimelineItemFramePreferenceKey.self,
							value: [TimelineItemFramePreference(articleID: timelineItem.article.articleID, frame: proxy.frame(in: .global))])
		}
	}
}
