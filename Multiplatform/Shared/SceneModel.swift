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
import RSCore

final class SceneModel: ObservableObject {
	
	@Published var refreshProgressState = RefreshProgressModel.State.none

	@Published var readButtonState: ArticleReadButtonState?
	@Published var starButtonState: ArticleStarButtonState?	

	private var refreshProgressModel: RefreshProgressModel? = nil
	private var articleIconSchemeHandler: ArticleIconSchemeHandler? = nil
	
	private(set) var webViewProvider: WebViewProvider? = nil
	private(set) var sidebarModel = SidebarModel()
	private(set) var timelineModel = TimelineModel()

	// MARK: Initialization API

	/// Prepares the SceneModel to be used in the views
	func startup() {
		sidebarModel.delegate = self
		timelineModel.delegate = self

		self.refreshProgressModel = RefreshProgressModel()
		self.refreshProgressModel!.$state.assign(to: self.$refreshProgressState)
		
		self.articleIconSchemeHandler = ArticleIconSchemeHandler(sceneModel: self)
		self.webViewProvider = WebViewProvider(articleIconSchemeHandler: self.articleIconSchemeHandler!)
		
		NotificationCenter.default.addObserver(self, selector: #selector(statusesDidChange(_:)), name: .StatusesDidChange, object: nil)
	}
	
	// MARK: Article Management API
	
	/// Retrieves the article before the given article in the Timeline
	func findPrevArticle(_ article: Article) -> Article? {
		return timelineModel.findPrevArticle(article)
	}
	
	/// Retrieves the article after the given article in the Timeline
	func findNextArticle(_ article: Article) -> Article? {
		return timelineModel.findNextArticle(article)
	}
	
	/// Returns the article with the given articleID
	func articleFor(_ articleID: String) -> Article? {
		return timelineModel.articleFor(articleID)
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

// MARK: Private

private extension SceneModel {
	
	// MARK: Notifications
	
	@objc func statusesDidChange(_ note: Notification) {
		guard let articleIDs = note.userInfo?[Account.UserInfoKey.articleIDs] as? Set<String> else {
			return
		}
		let selectedArticleIDs = timelineModel.selectedArticles.map { $0.articleID }
		if !articleIDs.intersection(selectedArticleIDs).isEmpty {
			updateArticleState()
		}
	}
	
	// MARK: Button State Updates
	
	func updateArticleState() {
		let articles = timelineModel.selectedArticles
		
		guard !articles.isEmpty else {
			readButtonState = nil
			starButtonState = nil
			return
		}
		
		if articles.anyArticleIsUnread() {
			readButtonState = .on
		} else if articles.anyArticleIsReadAndCanMarkUnread() {
			readButtonState = .off
		} else {
			readButtonState = nil
		}
		
		if articles.anyArticleIsUnstarred() {
			starButtonState = .on
		} else {
			starButtonState = .off
		}
	}

}
