//
//  CombinedRefreshProgress.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/7/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

// Combines the refresh progress of multiple accounts into one struct,
// for use by refresh status view and so on.

public struct CombinedRefreshProgress {

	public let numberOfTasks: Int
	public let numberRemaining: Int
	public let numberCompleted: Int
	public let isComplete: Bool
	public let isIndeterminate: Bool
	public let label: String

	init(numberOfTasks: Int, numberRemaining: Int, numberCompleted: Int, isIndeterminate: Bool, label: String) {
		self.numberOfTasks = max(numberOfTasks, 0)
		self.numberRemaining = max(numberRemaining, 0)
		self.numberCompleted = max(numberCompleted, 0)
		self.isComplete = numberRemaining < 1
		self.isIndeterminate = isIndeterminate
		self.label = label
	}

	public init(downloadProgressArray: [DownloadProgress]) {
		var numberOfDownloadsPossible = 0
		var numberOfDownloadsActive = 0
		var numberOfTasks = 0
		var numberRemaining = 0
		var numberCompleted = 0
		var isIndeterminate = false
		var isInprecise = false
		
		for downloadProgress in downloadProgressArray {
			numberOfDownloadsPossible += 1
			numberOfDownloadsActive += downloadProgress.isComplete ? 0 : 1
			numberOfTasks += downloadProgress.numberOfTasks
			numberRemaining += downloadProgress.numberRemaining
			numberCompleted += downloadProgress.numberCompleted
			
			if downloadProgress.isIndeterminate {
				isIndeterminate = true
			}
			
			if !downloadProgress.isPrecise {
				isInprecise = true
			}
		}

		var label = ""
		
		if numberOfDownloadsActive > 0 {
			if isInprecise {
				if numberOfDownloadsActive == 1 {
					if let activeName = downloadProgressArray.first(where: { $0.isComplete == false })?.name {
                        let formatString = String(localized: "Syncing %@", bundle: .module, comment: "Status bar progress")
						label = NSString(format: formatString as NSString, activeName) as String
					}
				} else {
                    let formatString = String(localized: "Syncing %@ accounts", bundle: .module, comment: "Status bar progress")
					label = NSString(format: formatString as NSString, NSNumber(value: numberOfDownloadsActive)) as String
				}
			} else {
                let formatString = String(localized: "%@ of %@", bundle: .module, comment: "Status bar progress")
				label = NSString(format: formatString as NSString, NSNumber(value: numberCompleted), NSNumber(value: numberOfTasks)) as String
			}
		}

		self.init(numberOfTasks: numberOfTasks, numberRemaining: numberRemaining, numberCompleted: numberCompleted, isIndeterminate: isIndeterminate, label: label)
	}
	
}
