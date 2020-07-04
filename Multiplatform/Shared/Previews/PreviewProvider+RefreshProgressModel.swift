//
//  PreviewProvider+RefreshProgressModel.swift
//  NetNewsWire
//
//  Created by Phil Viso on 7/3/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Account
import Foundation
import RSWeb
import SwiftUI

extension PreviewProvider {
	
	static func refreshProgressModel(lastRefreshDate: Date?,
									 tasksCompleted: Int,
									 totalTasks: Int) -> RefreshProgressModel {
		return RefreshProgressModel { () -> Date? in
			return lastRefreshDate
		} combinedRefreshProgressProvider: { () -> CombinedRefreshProgress in
			let progress = DownloadProgress(numberOfTasks: totalTasks)
			progress.numberRemaining = totalTasks - tasksCompleted
			
			return CombinedRefreshProgress(downloadProgressArray: [progress])
		}
	}
	
}
