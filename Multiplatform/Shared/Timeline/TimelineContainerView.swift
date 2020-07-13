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
	var feeds: [Feed]? = nil
	
	@ViewBuilder var body: some View {
		if let feeds = feeds {
			TimelineView()
				.modifier(TimelineToolbarModifier())
				.environmentObject(sceneModel.timelineModel)
				.onAppear {
					sceneModel.timelineModel.undoManager = undoManager
					sceneModel.timelineModel.fetchArticles(feeds: feeds)
				}
		} else {
			EmptyView()
		}
	}
	
}
