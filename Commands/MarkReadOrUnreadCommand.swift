//
//  MarkReadOrUnreadCommand.swift
//  Evergreen
//
//  Created by Brent Simmons on 10/26/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import Data

final class MarkReadOrUnreadCommand: UndoableCommand {
    
	static private let markReadActionName = NSLocalizedString("Mark Read", comment: "command")
	static private let markUnreadActionName = NSLocalizedString("Mark Unread", comment: "command")
	let undoActionName: String
	let redoActionName: String
    let articles: Set<Article>
	let undoManager: UndoManager
	let markingRead: Bool

	init?(initialArticles: [Article], markingRead: Bool, undoManager: UndoManager) {
        
        // Filter out articles already read.
		let articlesToMark = initialArticles.filter { markingRead ? !$0.status.read : $0.status.read }
		if articlesToMark.isEmpty {
			return nil
		}
		self.articles = Set(articlesToMark)

		self.markingRead = markingRead

 		self.undoManager = undoManager

		if markingRead {
			self.undoActionName = MarkReadOrUnreadCommand.markReadActionName
			self.redoActionName = MarkReadOrUnreadCommand.markReadActionName
		}
		else {
			self.undoActionName = MarkReadOrUnreadCommand.markUnreadActionName
			self.redoActionName = MarkReadOrUnreadCommand.markUnreadActionName
		}
    }
    
    func perform() {
        mark(read: markingRead)
		registerUndo()
    }
    
    func undo() {
        mark(read: !markingRead)
		registerRedo()
    }
}

private extension MarkReadOrUnreadCommand {
    
    func mark(read: Bool) {
        
        markArticles(articles, statusKey: .read, flag: read)
    }
}
