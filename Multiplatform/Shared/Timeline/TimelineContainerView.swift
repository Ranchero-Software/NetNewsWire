//
//  TimelineContainerView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/30/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct TimelineContainerView: View {
	
	@Environment(\.undoManager) var undoManager
	@EnvironmentObject private var sceneModel: SceneModel
	
	@State private var timelineItems = TimelineItems()
	@State private var isReadFiltered: Bool? = nil

	var body: some View {
		TimelineView(timelineItems: $timelineItems, isReadFiltered: $isReadFiltered)
			.modifier(TimelineToolbarModifier())
			.environmentObject(sceneModel.timelineModel)
			.onAppear {
				sceneModel.timelineModel.undoManager = undoManager
			}
			.onReceive(sceneModel.timelineModel.readFilterAndFeedsPublisher!) { (_, filtered) in
				isReadFiltered = filtered
			}
			.onReceive(sceneModel.timelineModel.timelineItemsSelectPublisher!) { (items, selectTimelineItemID) in
				timelineItems = items
				if let selectID = selectTimelineItemID {
					#if os(macOS)
					sceneModel.timelineModel.selectedTimelineItemIDs = Set([selectID])
					#else
					sceneModel.timelineModel.selectedTimelineItemID = selectID
					#endif
				}
			}
			.onReceive(sceneModel.timelineModel.articleStatusChangePublisher!) { articleIDs in
				articleIDs.forEach { articleID in
					if let position = timelineItems.index[articleID] {
						timelineItems.items[position].updateStatus()
					}
				}
			}
	}
	
}
