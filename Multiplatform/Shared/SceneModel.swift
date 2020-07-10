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
	
	var webViewProvider: WebViewProvider? = nil
	
	var undoManager: UndoManager?
	var undoableCommands = [UndoableCommand]()
	
	var sidebarModel: SidebarModel?
	var timelineModel: TimelineModel?
	var articleManager: ArticleManager?
	
	var currentArticle: Article? {
		return articleManager?.currentArticle
	}

	// MARK: Initialization API

	/// Prepares the SceneModel to be used in the views
	func startup() {
		self.refreshProgressModel = RefreshProgressModel()
		self.refreshProgressModel!.$state.assign(to: self.$refreshProgressState)
		
		self.articleIconSchemeHandler = ArticleIconSchemeHandler(sceneModel: self)
		self.webViewProvider = WebViewProvider(articleIconSchemeHandler: self.articleIconSchemeHandler!)
		
		NotificationCenter.default.addObserver(self, selector: #selector(statusesDidChange(_:)), name: .StatusesDidChange, object: nil)
	}
	
	// MARK: Article Management API

	/// Toggles the read indicator for the currently viewable article
	func toggleReadForCurrentArticle() {
		if let article = articleManager?.currentArticle {
			toggleRead(article)
		}
	}

	/// Toggles the read indicator for the given article
	func toggleRead(_ article: Article) {
		guard !article.status.read || article.isAvailableToMarkUnread else { return }
		markArticles([article], statusKey: .read, flag: !article.status.read)
	}

	/// Toggles the star indicator for the currently viewable article
	func toggleStarForCurrentArticle() {
		if let article = articleManager?.currentArticle {
			toggleStar(article)
		}
	}
	
	/// Toggles the star indicator for the given article
	func toggleStar(_ article: Article) {
		markArticles([article], statusKey: .starred, flag: !article.status.starred)
	}
	
	/// Retrieves the article before the given article in the Timeline
	func findPrevArticle(_ article: Article) -> Article? {
		return timelineModel?.findPrevArticle(article)
	}
	
	/// Retrieves the article after the given article in the Timeline
	func findNextArticle(_ article: Article) -> Article? {
		return timelineModel?.findNextArticle(article)
	}
	
	/// Marks the article as read and selects it in the Timeline.  Don't call until after the ArticleManager article has been set.
	func updateArticleSelection() {
		guard let article = currentArticle else { return }
		
		timelineModel?.selectArticle(article)
		
		if article.status.read {
			updateArticleState()
		} else {
			markArticles([article], statusKey: .read, flag: true)
		}
	}
	
	/// Returns the article with the given articleID
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

// MARK: UndoableCommandRunner

extension SceneModel: UndoableCommandRunner {
	
	func markArticlesWithUndo(_ articles: [Article], statusKey: ArticleStatus.Key, flag: Bool) {
		guard let undoManager = undoManager, let markReadCommand = MarkStatusCommand(initialArticles: articles, statusKey: statusKey, flag: flag, undoManager: undoManager) else {
			return
		}
		runCommand(markReadCommand)
	}

}

// MARK: Private

private extension SceneModel {
	
	// MARK: Notifications
	
	@objc func statusesDidChange(_ note: Notification) {
		guard let article = currentArticle, let articleIDs = note.userInfo?[Account.UserInfoKey.articleIDs] as? Set<String> else {
			return
		}
		if articleIDs.contains(article.articleID) {
			updateArticleState()
		}
	}
	
	// MARK: State Updates
	
	func updateArticleState() {
		guard let article = currentArticle else {
			readButtonState = nil
			starButtonState = nil
			return
		}
		
		if article.isAvailableToMarkUnread {
			readButtonState = article.status.read ? .off : .on
		} else {
			readButtonState = nil
		}
		
		starButtonState = article.status.starred ? .on : .off
	}

}
