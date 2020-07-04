//
//  SceneModel.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/28/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Account

final class SceneModel: ObservableObject {
	
	@Published var refreshProgressState = RefreshProgressModel.State.none
	
	var sidebarModel: SidebarModel?
	var timelineModel: TimelineModel?
	var articleModel: ArticleModel?
	
	private let refreshProgressModel: RefreshProgressModel
	
	init(refreshProgressModel: RefreshProgressModel = RefreshProgressModel()) {
		self.refreshProgressModel = refreshProgressModel
		self.refreshProgressModel.$state.assign(to: self.$refreshProgressState)
	}
	
}

// MARK: SidebarModelDelegate

extension SceneModel: SidebarModelDelegate {
	
	func unreadCount(for feed: Feed) -> Int {
		// TODO: Get the count from the timeline if Feed is the current timeline
		return feed.unreadCount
	}
	
}

// MARK: TimelineModelDelegate

extension SceneModel: TimelineModelDelegate {

	func timelineRequestedWebFeedSelection(_: TimelineModel, webFeed: WebFeed) {
	}
	
}

// MARK: ArticleModelDelegate

extension SceneModel: ArticleModelDelegate {

	
}
