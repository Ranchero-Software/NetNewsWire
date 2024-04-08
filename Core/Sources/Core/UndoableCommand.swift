//
//  UndoableCommand.swift
//  RSCore
//
//  Created by Brent Simmons on 10/24/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol UndoableCommand: AnyObject {

	@MainActor var undoActionName: String { get }
	@MainActor var redoActionName: String { get }
	@MainActor var undoManager: UndoManager { get }

	@MainActor func perform() // must call registerUndo()
	@MainActor func undo() // must call registerRedo()
}

extension UndoableCommand {

	@MainActor public func registerUndo() {

		undoManager.setActionName(undoActionName)
		undoManager.registerUndo(withTarget: self) { (target) in
			self.undo()
		}
	}

	@MainActor public func registerRedo() {
		
		undoManager.setActionName(redoActionName)
		undoManager.registerUndo(withTarget: self) { (target) in
			self.perform()
		}
	}
}

// Useful for view controllers.

public protocol UndoableCommandRunner: AnyObject {
    
	@MainActor var undoableCommands: [UndoableCommand] { get set }
	@MainActor var undoManager: UndoManager? { get }

	@MainActor func runCommand(_ undoableCommand: UndoableCommand)
	@MainActor func clearUndoableCommands()
}

public extension UndoableCommandRunner {
    
	@MainActor func runCommand(_ undoableCommand: UndoableCommand) {

        pushUndoableCommand(undoableCommand)
        undoableCommand.perform()
    }
    
	@MainActor func pushUndoableCommand(_ undoableCommand: UndoableCommand) {

        undoableCommands += [undoableCommand]
    }
    
	@MainActor func clearUndoableCommands() {

        // Useful, for example, when timeline is reloaded and the list of articles changes.
        // Otherwise things like Redo Mark Read are ambiguous.
        // (Do they apply to the previous articles or to the current articles?)
        
        guard let undoManager = undoManager else {
            return
        }
        
		for command in undoableCommands {
			undoManager.removeAllActions(withTarget: command)
		}
        undoableCommands = [UndoableCommand]()
    }
}
