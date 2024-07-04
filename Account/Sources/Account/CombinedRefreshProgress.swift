//
//  CombinedRefreshProgress.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/7/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Web

// Combines the refresh progress of multiple accounts into one struct,
// for use by refresh status view and so on.

public struct CombinedRefreshProgress: Sendable {

	public let numberOfTasks: Int
	public let numberRemaining: Int
	public let numberCompleted: Int
	public let isComplete: Bool

	init(numberOfTasks: Int, numberRemaining: Int, numberCompleted: Int) {
		self.numberOfTasks = max(numberOfTasks, 0)
		self.numberRemaining = max(numberRemaining, 0)
		self.numberCompleted = max(numberCompleted, 0)
		self.isComplete = numberRemaining < 1
	}

	public init(downloadProgressArray: [DownloadProgress]) {
		var numberOfTasks = 0
		var numberRemaining = 0
		var numberCompleted = 0

		for downloadProgress in downloadProgressArray {
			let taskCounts = downloadProgress.taskCounts
			numberOfTasks += taskCounts.numberOfTasks
			numberRemaining += taskCounts.numberRemaining
			numberCompleted += taskCounts.numberCompleted
		}

		self.init(numberOfTasks: numberOfTasks, numberRemaining: numberRemaining, numberCompleted: numberCompleted)
	}
}
