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
	
	var undoManager: UndoManager?
	var undoableCommands = [UndoableCommand]()
	
	var sidebarModel: SidebarModel?
	var timelineModel: TimelineModel?
	var articleModel: ArticleModel?
	
	private var refreshProgressModel: RefreshProgressModel? = nil
	private var articleIconSchemeHandler: ArticleIconSchemeHandler? = nil
	private var webViewProvider: WebViewProvider? = nil
	
	// MARK: Initialization API

	func startup() {
		self.refreshProgressModel = RefreshProgressModel()
		self.refreshProgressModel!.$state.assign(to: self.$refreshProgressState)
		
		self.articleIconSchemeHandler = ArticleIconSchemeHandler(sceneModel: self)
		self.webViewProvider = WebViewProvider(articleIconSchemeHandler: self.articleIconSchemeHandler!)
	}
	
	// MARK: Article Status Change API

	func toggleReadForCurrentArticle() {
		articleModel?.toggleReadForCurrentArticle()
	}
	
	func toggleRead(_ article: Article) {
		guard !article.status.read || article.isAvailableToMarkUnread else { return }
		markArticles([article], statusKey: .read, flag: !article.status.read)
	}

	func toggleStarForCurrentArticle() {
		articleModel?.toggleStarForCurrentArticle()
	}
	
	func toggleStar(_ article: Article) {
		markArticles([article], statusKey: .starred, flag: !article.status.starred)
	}
	
	// MARK: Resource lookup API
	
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
	
	var articleModelWebViewProvider: WebViewProvider? {
		return webViewProvider
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
	

}
