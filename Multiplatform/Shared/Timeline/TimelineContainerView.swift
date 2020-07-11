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
	
	@EnvironmentObject private var sceneModel: SceneModel
	@StateObject private var timelineModel = TimelineModel()
	var feeds: [Feed]? = nil
	
	@ViewBuilder var body: some View {
		if let feeds = feeds {
			TimelineView()
				.modifier(TimelineTitleModifier(title: timelineModel.nameForDisplay))
				.modifier(TimelineToolbarModifier())
				.environmentObject(timelineModel)
				.onAppear {
					sceneModel.timelineModel = timelineModel
					timelineModel.delegate = sceneModel
					timelineModel.rebuildTimelineItems(feeds: feeds)
				}
		} else {
			EmptyView()
		}
	}
	
}
