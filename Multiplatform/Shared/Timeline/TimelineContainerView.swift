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
	var feed: Feed? = nil
	
	@ViewBuilder var body: some View {
		if let feed = feed {
			TimelineView()
				.environmentObject(timelineModel)
				.onAppear {
					sceneModel.timelineModel = timelineModel
					timelineModel.delegate = sceneModel
					timelineModel.rebuildTimelineItems(feed)
				}
				.overlay(Group {
					#if os(iOS)
					TimelineToolbar()
					#endif
				},alignment: .bottom)
		} else {
			EmptyView()
		}
	}
	
}
