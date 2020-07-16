//
//  RefreshProgressModel.swift
//  NetNewsWire
//
//  Created by Phil Viso on 7/2/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Combine
import RSCore
import Account

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
		
	private static let lastRefreshDateTextUpdateInterval = 60
	private static let lastRefreshDateTextRelativeDateFormattingThreshold = 60.0
	
	func startup() {
		updateState()
		observeRefreshProgress()
		scheduleLastRefreshDateTextUpdate()
	}
	
	// MARK: Observing account changes
	
	private func observeRefreshProgress() {
		NotificationCenter.default.addObserver(self, selector: #selector(accountRefreshProgressDidChange), name: .AccountRefreshProgressDidChange, object: nil)
	}
	
	// MARK: Refreshing state
	
	@objc private func accountRefreshProgressDidChange() {
		CoalescingQueue.standard.add(self, #selector(updateState))
	}
	
	@objc private func updateState() {
		let progress = AccountManager.shared.combinedRefreshProgress
		
		if !progress.isComplete {
			let fractionCompleted = Float(progress.numberCompleted) / Float(progress.numberOfTasks)
			self.state = .refreshProgress(fractionCompleted)
		} else if let lastRefreshDate = AccountManager.shared.lastArticleFetchEndTime {
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
