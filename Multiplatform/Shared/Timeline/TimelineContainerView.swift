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
				.toolbar {
					#if os(iOS)
					ToolbarItem {
						Button(action: {
						}, label: {
							AppAssets.markAllAsReadImage
								.foregroundColor(.accentColor)
						}).help("Mark All As Read")
					}
					ToolbarItem {
						Spacer()
					}
					ToolbarItem {
						Text("Last updated")
							.font(.caption)
							.foregroundColor(.secondary)
					}
					ToolbarItem {
						Spacer()
					}
					ToolbarItem {
						Button(action: {
						}, label: {
							AppAssets.nextUnreadArticleImage
								.resizable()
								.scaledToFit()
								.frame(width: 22, height: 22, alignment: .center)
						})
					}
					#endif
				}
		} else {
			EmptyView()
		}
	}
	
}
