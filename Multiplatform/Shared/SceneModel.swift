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
	
	@Published var markAllAsReadButtonState: Bool?
	@Published var nextUnreadButtonState: Bool?
	@Published var readButtonState: Bool?
	@Published var starButtonState: Bool?
	@Published var extractorButtonState: ArticleExtractorButtonState?
	@Published var openInBrowserButtonState: Bool?
	@Published var shareButtonState: Bool?

	@Published var accountErrorMessage = ""

	var selectedArticles: [Article] {
		timelineModel.selectedArticles
	}
	
	private var refreshProgressModel: RefreshProgressModel? = nil
	private var articleIconSchemeHandler: ArticleIconSchemeHandler? = nil
	
	private(set) var webViewProvider: WebViewProvider? = nil
	private(set) var sidebarModel = SidebarModel()
	private(set) var timelineModel = TimelineModel()

	private var cancellables = Set<AnyCancellable>()

	// MARK: Initialization API

	/// Prepares the SceneModel to be used in the views
	func startup() {
		sidebarModel.delegate = self
		timelineModel.delegate = self
		timelineModel.startup()
		
		self.articleIconSchemeHandler = ArticleIconSchemeHandler(sceneModel: self)
		self.webViewProvider = WebViewProvider(articleIconSchemeHandler: self.articleIconSchemeHandler!)
		
		NotificationCenter.default.addObserver(self, selector: #selector(statusesDidChange(_:)), name: .StatusesDidChange, object: nil)

		timelineModel.$articles.sink { [weak self] articles in
			self?.updateMarkAllAsReadButtonsState(articles: articles)
		}.store(in: &cancellables)

		timelineModel.$selectedArticles.sink { [weak self] articles in
			self?.updateArticleButtonsState(selectedArticles: articles)
		}.store(in: &cancellables)
	}
	
	// MARK: Article Management API
	
	/// Marks all the articles in the Timeline as read
	func markAllAsRead() {
		timelineModel.markAllAsRead()
	}
	
	/// Toggles the read status for the selected articles
	func toggleReadStatusForSelectedArticles() {
		timelineModel.toggleReadStatusForSelectedArticles()
	}
	
	/// Toggles the star status for the selected articles
	func toggleStarredStatusForSelectedArticles() {
		timelineModel.toggleStarredStatusForSelectedArticles()
	}

	/// Opens the selected article in an external browser
	func openSelectedArticleInBrowser() {
		timelineModel.openSelectedArticleInBrowser()
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

	var selectedFeeds: Published<[Feed]>.Publisher {
		return sidebarModel.$selectedFeeds
	}
	
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
		updateMarkAllAsReadButtonsState(articles: timelineModel.articles)
		let selectedArticleIDs = timelineModel.selectedArticles.map { $0.articleID }
		if !articleIDs.intersection(selectedArticleIDs).isEmpty {
			updateArticleButtonsState(selectedArticles: timelineModel.selectedArticles)
		}
	}
	
	// MARK: Button State Updates
	
	func updateMarkAllAsReadButtonsState(articles: [Article]) {
		if articles.canMarkAllAsRead() {
			markAllAsReadButtonState = false
		} else {
			markAllAsReadButtonState = nil
		}
	}
	
	func updateArticleButtonsState(selectedArticles: [Article]) {
		guard !selectedArticles.isEmpty else {
			readButtonState = nil
			starButtonState = nil
			openInBrowserButtonState = nil
			shareButtonState = nil
			return
		}
		
		if selectedArticles.anyArticleIsUnread() {
			readButtonState = true
		} else if selectedArticles.anyArticleIsReadAndCanMarkUnread() {
			readButtonState = false
		} else {
			readButtonState = nil
		}
		
		if selectedArticles.anyArticleIsUnstarred() {
			starButtonState = false
		} else {
			starButtonState = true
		}
		
		if selectedArticles.count == 1, selectedArticles.first?.preferredLink != nil {
			openInBrowserButtonState = true
			shareButtonState = true
		} else {
			openInBrowserButtonState = nil
			shareButtonState = nil
		}
	}

}
