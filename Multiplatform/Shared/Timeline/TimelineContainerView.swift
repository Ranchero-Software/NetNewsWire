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

	@ViewBuilder var body: some View {
		TimelineView(timelineItems: $timelineItems, isReadFiltered: $isReadFiltered)
			.modifier(TimelineToolbarModifier())
			.environmentObject(sceneModel.timelineModel)
			.onAppear {
				sceneModel.timelineModel.undoManager = undoManager
			}
			.onReceive(sceneModel.timelineModel.readFilterAndFeedsPublisher!) { (_, filtered) in
				isReadFiltered = filtered
			}
			.onReceive(sceneModel.timelineModel.timelineItemsPublisher!) { items in
				timelineItems = items
			}
			.onReceive(sceneModel.timelineModel.articleStatusChangePublisher!) { articleIDs in
				articleIDs.forEach { articleID in
					if let position = timelineItems.index[articleID] {
						// This animation will trigger a deselect on iPhones and iPads, so we will disable it for now
						#if os(macOS)
						if timelineItems.items[position].isReadOnly {
							withAnimation {
								timelineItems.items[position].updateStatus()
							}
						} else {
							timelineItems.items[position].updateStatus()
						}
						#else
						timelineItems.items[position].updateStatus()
						#endif
					}
				}
			}
	}
	
}
