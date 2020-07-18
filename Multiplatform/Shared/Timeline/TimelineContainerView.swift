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
	
	@ViewBuilder var body: some View {
		TimelineView()
			.modifier(TimelineToolbarModifier())
			.environmentObject(sceneModel.timelineModel)
			.onAppear {
				sceneModel.timelineModel.undoManager = undoManager
			}
	}
	
}
