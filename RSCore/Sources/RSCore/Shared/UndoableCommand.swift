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

	func perform() // must call registerUndo()
	func undo() // must call registerRedo()
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
			self.perform()
		}
	}
}

// Useful for view controllers.

public protocol UndoableCommandRunner: class {
    
    var undoableCommands: [UndoableCommand] { get set }
    var undoManager: UndoManager? { get }
    
    func runCommand(_ undoableCommand: UndoableCommand)
    func clearUndoableCommands()
}

public extension UndoableCommandRunner {
    
    func runCommand(_ undoableCommand: UndoableCommand) {
        
        pushUndoableCommand(undoableCommand)
        undoableCommand.perform()
    }
    
    func pushUndoableCommand(_ undoableCommand: UndoableCommand) {
        
        undoableCommands += [undoableCommand]
    }
    
    func clearUndoableCommands() {
        
        // Useful, for example, when timeline is reloaded and the list of articles changes.
        // Otherwise things like Redo Mark Read are ambiguous.
        // (Do they apply to the previous articles or to the current articles?)
        
        guard let undoManager = undoManager else {
            return
        }
        undoableCommands.forEach { undoManager.removeAllActions(withTarget: $0) }
        undoableCommands = [UndoableCommand]()
    }
}
