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
	@Published var accountSyncErrors: [AccountSyncError] = []

	var selectedArticles: [Article] {
		timelineModel.selectedArticles
	}
	
	private var refreshProgressModel: RefreshProgressModel? = nil
	private var articleIconSchemeHandler: ArticleIconSchemeHandler? = nil
	
	private(set) var webViewProvider: WebViewProvider? = nil
	private(set) lazy var sidebarModel = SidebarModel(delegate: self)
	private(set) lazy var timelineModel = TimelineModel(delegate: self)

	private var cancellables = Set<AnyCancellable>()

	// MARK: Initialization API

	/// Prepares the SceneModel to be used in the views
	func startup() {
		self.articleIconSchemeHandler = ArticleIconSchemeHandler(sceneModel: self)
		self.webViewProvider = WebViewProvider(articleIconSchemeHandler: self.articleIconSchemeHandler!)

		subscribeToAccountSyncErrors()
		subscribeToToolbarChangeEvents()
	}
	
	// MARK: Navigation API
	
	/// Goes to the next unread item found in Sidebar and Timeline order, top to bottom
	func goToNextUnread() {
		if !timelineModel.goToNextUnread() {
			timelineModel.selectNextUnreadSubject.send(true)
			sidebarModel.selectNextUnread.send()
		}
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

	var selectedFeedsPublisher: AnyPublisher<[Feed], Never>? {
		return sidebarModel.selectedFeedsPublisher
	}
	
	func timelineRequestedWebFeedSelection(_: TimelineModel, webFeed: WebFeed) {
	}
	
}

// MARK: Private

private extension SceneModel {
	
	// MARK: Subscriptions
	func subscribeToToolbarChangeEvents() {
		guard let selectedArticlesPublisher = timelineModel.selectedArticlesPublisher else { return }
		
		NotificationCenter.default.publisher(for: .UnreadCountDidChange)
			.compactMap { $0.object as? AccountManager }
			.sink {  [weak self] accountManager in
				self?.updateNextUnreadButtonState(accountManager: accountManager)
			}.store(in: &cancellables)

		let blankNotification = Notification(name: .StatusesDidChange)
		let statusesDidChangePublisher = NotificationCenter.default.publisher(for: .StatusesDidChange).prepend(blankNotification)

		statusesDidChangePublisher
			.combineLatest(selectedArticlesPublisher)
			.sink { [weak self] _, selectedArticles in
				self?.updateArticleButtonsState(selectedArticles: selectedArticles)
			}
			.store(in: &cancellables)

		statusesDidChangePublisher
			.combineLatest(timelineModel.articlesSubject)
			.sink { [weak self] _, articles in
				self?.updateMarkAllAsReadButtonsState(articles: articles)
			}
			.store(in: &cancellables)
	}
	
	func subscribeToAccountSyncErrors() {
		NotificationCenter.default.publisher(for: .AccountsDidFailToSyncWithErrors)
			.sink { [weak self] notification in
				guard let syncErrors = notification.userInfo?[Account.UserInfoKey.syncErrors] as? [AccountSyncError] else {
					return
				}
				self?.accountSyncErrors = syncErrors
			}.store(in: &cancellables)
	}
	
	// MARK: Button State Updates
	
	func updateNextUnreadButtonState(accountManager: AccountManager) {
		if accountManager.unreadCount > 0 {
			self.nextUnreadButtonState = false
		} else {
			self.nextUnreadButtonState = nil
		}
	}
	
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
