//
//  SceneModel.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/28/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Combine
import Account
import Articles
import RSCore

final class SceneModel: ObservableObject {
	
	@Published var refreshProgressState = RefreshProgressModel.State.none

	@Published var markAllAsReadButtonState: Bool?
	@Published var nextUnreadButtonState: Bool?
	@Published var readButtonState: Bool?
	@Published var starButtonState: Bool?
	@Published var extractorButtonState: ArticleExtractorButtonState?
	@Published var openInBrowserButtonState: Bool?
	@Published var shareButtonState: Bool?

	var selectedArticles: [Article] {
		timelineModel.selectedArticles
	}
	
	private var refreshProgressModel: RefreshProgressModel? = nil
	private var articleIconSchemeHandler: ArticleIconSchemeHandler? = nil
	
	private(set) var webViewProvider: WebViewProvider? = nil
	private(set) var sidebarModel = SidebarModel()
	private(set) var timelineModel = TimelineModel()

	private var selectedArticlesCancellable: AnyCancellable?

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

		selectedArticlesCancellable = timelineModel.$selectedArticles.sink { [weak self] articles in
			self?.updateArticleButtonsState(articles: articles)
		}
	}
	
	// MARK: Article Management API
	
	func toggleReadStatusForSelectedArticles() {
		timelineModel.toggleReadStatusForSelectedArticles()
	}
	
	func toggleStarredStatusForSelectedArticles() {
		timelineModel.toggleStarredStatusForSelectedArticles()
	}
	
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
			updateArticleButtonsState(articles: timelineModel.selectedArticles)
		}
	}
	
	// MARK: Button State Updates
	
	func updateArticleButtonsState(articles: [Article]) {
		guard !articles.isEmpty else {
			readButtonState = nil
			starButtonState = nil
			return
		}
		
		if articles.anyArticleIsUnread() {
			readButtonState = true
		} else if articles.anyArticleIsReadAndCanMarkUnread() {
			readButtonState = false
		} else {
			readButtonState = nil
		}
		
		if articles.anyArticleIsUnstarred() {
			starButtonState = false
		} else {
			starButtonState = true
		}
		
		if articles.count == 1, articles.first?.preferredLink != nil {
			openInBrowserButtonState = true
			shareButtonState = true
		} else {
			openInBrowserButtonState = nil
			shareButtonState = nil
		}
	}

}
