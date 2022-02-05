//
//  MarkStatusCommand.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/26/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import Articles

// Mark articles read/unread, starred/unstarred, deleted/undeleted.

final class MarkStatusCommand: UndoableCommand {
    
	let undoActionName: String
	let redoActionName: String
    let articles: Set<Article>
	let undoManager: UndoManager
	let flag: Bool
	let statusKey: ArticleStatus.Key
	var completion: (() -> Void)? = nil

	init?(initialArticles: [Article], statusKey: ArticleStatus.Key, flag: Bool, undoManager: UndoManager, completion: (() -> Void)? = nil) {
        
        // Filter out articles that already have the desired status or can't be marked.
		let articlesToMark = MarkStatusCommand.filteredArticles(initialArticles, statusKey, flag)
		if articlesToMark.isEmpty {
			completion?()
			return nil
		}
		self.articles = Set(articlesToMark)

		self.flag = flag
		self.statusKey = statusKey
 		self.undoManager = undoManager
		self.completion = completion

		let actionName = MarkStatusCommand.actionName(statusKey, flag)
		self.undoActionName = actionName
		self.redoActionName = actionName
    }

	convenience init?(initialArticles: [Article], markingRead: Bool, undoManager: UndoManager, completion: (() -> Void)? = nil) {
		self.init(initialArticles: initialArticles, statusKey: .read, flag: markingRead, undoManager: undoManager, completion: completion)
	}

	convenience init?(initialArticles: [Article], markingStarred: Bool, undoManager: UndoManager, completion: (() -> Void)? = nil) {
		self.init(initialArticles: initialArticles, statusKey: .starred, flag: markingStarred, undoManager: undoManager, completion: completion)
	}

    func perform() {
		mark(statusKey, flag)
 		registerUndo()
    }
    
    func undo() {
		mark(statusKey, !flag)
		registerRedo()
    }
}

private extension MarkStatusCommand {
    
	func mark(_ statusKey: ArticleStatus.Key, _ flag: Bool) {
        markArticles(articles, statusKey: statusKey, flag: flag, completion: completion)
		completion = nil
    }

	static private let markReadActionName = NSLocalizedString("MARK_READ", comment: "command")
	static private let markUnreadActionName = NSLocalizedString("MARK_UNREAD", comment: "command")
	static private let markStarredActionName = NSLocalizedString("MARK_STARRED", comment: "command")
	static private let markUnstarredActionName = NSLocalizedString("MARK_UNSTARRED", comment: "command")

	static func actionName(_ statusKey: ArticleStatus.Key, _ flag: Bool) -> String {

		switch statusKey {
		case .read:
			return flag ? markReadActionName : markUnreadActionName
		case .starred:
			return flag ? markStarredActionName : markUnstarredActionName
		}
	}

	static func filteredArticles(_ articles: [Article], _ statusKey: ArticleStatus.Key, _ flag: Bool) -> [Article] {

		return articles.filter{ article in
			guard article.status.boolStatus(forKey: statusKey) != flag else { return false }
			guard statusKey == .read else { return true }
			guard !article.status.read || article.isAvailableToMarkUnread else { return false }
			return true
		}
		
	}
}
