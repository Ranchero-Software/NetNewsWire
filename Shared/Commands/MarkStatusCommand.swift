//
//  MarkStatusCommand.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/26/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import Account
import Articles

// Mark articles read/unread, starred/unstarred, deleted/undeleted.
//
// Directly marked articles are ones that were statused by selecting with a cursor or were selected by group.
// Indirectly marked articles didn't have any focus and were picked up using a Mark All command like Mark All as Read.
//
// See discussion for details: https://github.com/Ranchero-Software/NetNewsWire/issues/3734

public extension Notification.Name {
	static let MarkStatusCommandDidDirectMarking = Notification.Name("MarkStatusCommandDid√DirectMarking")
	static let MarkStatusCommandDidUndoDirectMarking = Notification.Name("MarkStatusCommandDidUndoDirectMarking")
}

final class MarkStatusCommand: UndoableCommand {
    
	let undoActionName: String
	let redoActionName: String
    let articles: Set<Article>
	let undoManager: UndoManager
	let flag: Bool
	let directlyMarked: Bool
	let statusKey: ArticleStatus.Key
	var completion: (() -> Void)? = nil

	init?(initialArticles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool, directlyMarked: Bool, undoManager: UndoManager, completion: (() -> Void)? = nil) {
        
        // Filter out articles that already have the desired status or can't be marked.
		let articlesToMark = MarkStatusCommand.filteredArticles(initialArticles, statusKey, flag)
		if articlesToMark.isEmpty {
			completion?()
			return nil
		}
		self.articles = articlesToMark

		self.directlyMarked = directlyMarked
		self.flag = flag
		self.statusKey = statusKey
 		self.undoManager = undoManager
		self.completion = completion

		let actionName = MarkStatusCommand.actionName(statusKey, flag)
		self.undoActionName = actionName
		self.redoActionName = actionName
    }

	convenience init?(initialArticles: [Article], statusKey: ArticleStatus.Key, flag: Bool, directlyMarked: Bool, undoManager: UndoManager, completion: (() -> Void)? = nil) {
		self.init(initialArticles: Set(initialArticles), statusKey: .read, flag: flag, directlyMarked: directlyMarked, undoManager: undoManager, completion: completion)
	}

	convenience init?(initialArticles: Set<Article>, markingRead: Bool, directlyMarked: Bool, undoManager: UndoManager, completion: (() -> Void)? = nil) {
		self.init(initialArticles: initialArticles, statusKey: .read, flag: markingRead, directlyMarked: directlyMarked, undoManager: undoManager, completion: completion)
	}

	convenience init?(initialArticles: [Article], markingRead: Bool, directlyMarked: Bool, undoManager: UndoManager, completion: (() -> Void)? = nil) {
		self.init(initialArticles: initialArticles, statusKey: .read, flag: markingRead, directlyMarked: directlyMarked, undoManager: undoManager, completion: completion)
	}

	convenience init?(initialArticles: Set<Article>, markingStarred: Bool, directlyMarked: Bool, undoManager: UndoManager, completion: (() -> Void)? = nil) {
		self.init(initialArticles: initialArticles, statusKey: .starred, flag: markingStarred, directlyMarked: directlyMarked, undoManager: undoManager, completion: completion)
	}

	convenience init?(initialArticles: [Article], markingStarred: Bool, directlyMarked: Bool, undoManager: UndoManager, completion: (() -> Void)? = nil) {
		self.init(initialArticles: initialArticles, statusKey: .starred, flag: markingStarred, directlyMarked: directlyMarked, undoManager: undoManager, completion: completion)
	}

    func perform() {
		mark(statusKey, flag)
		if directlyMarked {
			markStatusCommandDidDirectMarking()
		}
 		registerUndo()
    }
    
    func undo() {
		mark(statusKey, !flag)
		if directlyMarked {
			markStatusCommandDidUndoDirectMarking()
		}
		registerRedo()
    }
}

private extension MarkStatusCommand {
    
	func mark(_ statusKey: ArticleStatus.Key, _ flag: Bool) {
        markArticles(articles, statusKey: statusKey, flag: flag, completion: completion)
		completion = nil
    }
	
	func markStatusCommandDidDirectMarking() {
		NotificationCenter.default.post(name: .MarkStatusCommandDidDirectMarking, object: self, userInfo: [Account.UserInfoKey.articles: articles,
																										   Account.UserInfoKey.statusKey: statusKey,
																										   Account.UserInfoKey.statusFlag: flag])
	}

	func markStatusCommandDidUndoDirectMarking() {
		NotificationCenter.default.post(name: .MarkStatusCommandDidUndoDirectMarking, object: self, userInfo: [Account.UserInfoKey.articles: articles,
																											   Account.UserInfoKey.statusKey: statusKey,
																											   Account.UserInfoKey.statusFlag: flag])
	}

	static private let markReadActionName = NSLocalizedString("Mark Read", comment: "command")
	static private let markUnreadActionName = NSLocalizedString("Mark Unread", comment: "command")
	static private let markStarredActionName = NSLocalizedString("Mark Starred", comment: "command")
	static private let markUnstarredActionName = NSLocalizedString("Mark Unstarred", comment: "command")

	static func actionName(_ statusKey: ArticleStatus.Key, _ flag: Bool) -> String {

		switch statusKey {
		case .read:
			return flag ? markReadActionName : markUnreadActionName
		case .starred:
			return flag ? markStarredActionName : markUnstarredActionName
		}
	}

	static func filteredArticles(_ articles: Set<Article>, _ statusKey: ArticleStatus.Key, _ flag: Bool) -> Set<Article> {

		return articles.filter{ article in
			guard article.status.boolStatus(forKey: statusKey) != flag else { return false }
			guard statusKey == .read else { return true }
			guard !article.status.read || article.isAvailableToMarkUnread else { return false }
			return true
		}
		
	}
	
}
