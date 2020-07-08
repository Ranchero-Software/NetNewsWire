//
//  SceneModel.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/28/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Account
import Articles

final class SceneModel: ObservableObject {
	
	@Published var refreshProgressState = RefreshProgressModel.State.none
	
	var sidebarModel: SidebarModel?
	var timelineModel: TimelineModel?
	var articleModel: ArticleModel?
	
	private var refreshProgressModel: RefreshProgressModel? = nil
	private var _webViewProvider: WebViewProvider? = nil
	
	// MARK: API

	func startup() {
		self.refreshProgressModel = RefreshProgressModel()
		self.refreshProgressModel!.$state.assign(to: self.$refreshProgressState)
		
		self._webViewProvider = WebViewProvider(sceneModel: self)
	}

	func articleFor(_ articleID: String) -> Article? {
		return timelineModel?.articleFor(articleID)
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
	
	var webViewProvider: WebViewProvider? {
		return _webViewProvider
	}

	func findPrevArticle(_: ArticleModel, article: Article) -> Article? {
		return timelineModel?.findPrevArticle(article)
	}
	
	func findNextArticle(_: ArticleModel, article: Article) -> Article? {
		return timelineModel?.findNextArticle(article)
	}
	
	func selectArticle(_: ArticleModel, article: Article) {
		timelineModel?.selectArticle(article)
	}
	
}

// MARK: Private

private extension SceneModel {
	
}
