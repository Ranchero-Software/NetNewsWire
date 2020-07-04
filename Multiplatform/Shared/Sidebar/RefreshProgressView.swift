//
//  RefreshProgressView.swift
//  NetNewsWire
//
//  Created by Phil Viso on 7/2/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct RefreshProgressView: View {
	
	@EnvironmentObject var sceneModel: SceneModel
	
	@ViewBuilder var body: some View {
		switch sceneModel.refreshProgressState {
		case .refreshProgress(let progress):
			ProgressView(value: progress)
				.frame(width: progressViewWidth())
		case .lastRefreshDateText(let text):
			Text(text)
				.lineLimit(1)
				.font(.caption)
				.foregroundColor(.secondary)
		case .none:
			EmptyView()
		}
	}
	
	// MARK -
	
	private func progressViewWidth() -> CGFloat {
		#if os(iOS)
		return 100.0
		#endif
		
		#if os(macOS)
		return 40.0
		#endif
	}
	
}

struct RefreshProgressView_Previews: PreviewProvider {
	static var previews: some View {
		Group {
			RefreshProgressView()
				.environmentObject(refreshProgressModel(lastRefreshDate: nil, tasksCompleted: 1, totalTasks: 2))
				.previewDisplayName("Refresh in progress")
						
			RefreshProgressView()
				.environmentObject(refreshProgressModel(lastRefreshDate: Date(timeIntervalSinceNow: -120.0), tasksCompleted: 0, totalTasks: 0))
				.previewDisplayName("Last refreshed with date")
		}
		.previewLayout(.sizeThatFits)
    }
}
