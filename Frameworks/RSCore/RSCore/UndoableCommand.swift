//
//  UndoableCommand.swift
//  RSCore
//
//  Created by Brent Simmons on 10/24/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol UndoableCommand: class {

	var undoActionName: String { get }
	var redoActionName: String { get }
	var undoManager: UndoManager { get }

	func perform()
	func undo()
	func redo()
}

extension UndoableCommand {

	public func registerUndo() {

		undoManager.setActionName(undoActionName)
		undoManager.registerUndo(withTarget: self) { (target) in
			self.undo()
		}
	}

	public func registerRedo() {
		
		undoManager.setActionName(redoActionName)
		undoManager.registerUndo(withTarget: self) { (target) in
			self.redo()
		}
	}
}
