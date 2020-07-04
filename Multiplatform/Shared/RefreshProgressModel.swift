//
//  RefreshProgressModel.swift
//  NetNewsWire
//
//  Created by Phil Viso on 7/2/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Account
import Combine
import Foundation
import SwiftUI

class RefreshProgressModel: ObservableObject {
	
	enum State {
		case refreshProgress(Float)
		case lastRefreshDateText(String)
		case none
	}
		
	@Published var state = State.none
	
	private static var dateFormatter: RelativeDateTimeFormatter = {
		let formatter = RelativeDateTimeFormatter()
		formatter.dateTimeStyle = .named
		
		return formatter
	}()
		
	private let lastRefreshDate: () -> Date?
	private let combinedRefreshProgress: () -> CombinedRefreshProgress
	
	private static let lastRefreshDateTextUpdateInterval = 60
	private static let lastRefreshDateTextRelativeDateFormattingThreshold = 60.0
	
	init(lastRefreshDateProvider: @escaping () -> Date?,
		 combinedRefreshProgressProvider: @escaping () -> CombinedRefreshProgress) {
		self.lastRefreshDate = lastRefreshDateProvider
		self.combinedRefreshProgress = combinedRefreshProgressProvider
		
		updateState()
		
		observeRefreshProgress()
		scheduleLastRefreshDateTextUpdate()
	}
	
	// MARK: Observing account changes
	
	private func observeRefreshProgress() {
		NotificationCenter.default.addObserver(self, selector: #selector(updateState), name: .AccountRefreshProgressDidChange, object: nil)
	}
	
	// MARK: Refreshing state
	
	@objc private func updateState() {
		let progress = combinedRefreshProgress()
		
		if !progress.isComplete {
			let fractionCompleted = Float(progress.numberCompleted) / Float(progress.numberOfTasks)
			self.state = .refreshProgress(fractionCompleted)
		} else if let lastRefreshDate = self.lastRefreshDate() {
			let text = localizedLastRefreshText(lastRefreshDate: lastRefreshDate)
			self.state = .lastRefreshDateText(text)
		} else {
			self.state = .none
		}
	}
	
	private func scheduleLastRefreshDateTextUpdate() {
		DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(Self.lastRefreshDateTextUpdateInterval)) {
			self.updateState()
			self.scheduleLastRefreshDateTextUpdate()
		}
	}
	
	private func localizedLastRefreshText(lastRefreshDate: Date) -> String {
		let now = Date()
		
		if now > lastRefreshDate.addingTimeInterval(Self.lastRefreshDateTextRelativeDateFormattingThreshold) {
			let localizedDate = Self.dateFormatter.localizedString(for: lastRefreshDate, relativeTo: now)
			let formatString = NSLocalizedString("Updated %@", comment: "Updated") as NSString
			
			return NSString.localizedStringWithFormat(formatString, localizedDate) as String
		} else {
			return NSLocalizedString("Updated Just Now", comment: "Updated Just Now")
		}
	}
		
}

extension RefreshProgressModel {
	
	convenience init() {
		self.init(
			lastRefreshDateProvider: { AccountManager.shared.lastArticleFetchEndTime },
			combinedRefreshProgressProvider: { AccountManager.shared.combinedRefreshProgress }
		)
	}
		
}
