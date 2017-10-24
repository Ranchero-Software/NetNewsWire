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

	func perform()
	func undo()
	func redo()
}
