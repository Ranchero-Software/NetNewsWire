//
//  MarkAllReadCommand.swift
//  Evergreen
//
//  Created by Brent Simmons on 10/26/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import Data

final class MarkAllReadCommand: UndoableCommand {
    
    static private let actionName = NSLocalizedString("Mark All as Read", comment: "command")
    let undoActionName = actionName
    let redoActionName = actionName
    let articles: Set<Article>
	let undoManager: UndoManager
    
	init?(initialArticles: [Article], undoManager: UndoManager) {
        
        // Filter out articles already read.
        let unreadArticles = initialArticles.filter { !$0.status.read }
		if unreadArticles.isEmpty {
			return nil
		}

        self.articles = Set(unreadArticles)
		self.undoManager = undoManager
    }
    
    func perform() {
        mark(read: true)
		registerUndo()
    }
    
    func undo() {
        mark(read: false)
		registerRedo()
    }
    
    func redo() {
        perform()
    }
}

private extension MarkAllReadCommand {
    
    func mark(read: Bool) {
        
        markArticles(articles, statusKey: .read, flag: read)
    }
}
