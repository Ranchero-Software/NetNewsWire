//
//  TimelineModel.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/30/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import Account

protocol TimelineModelDelegate: class {
	func timelineRequestedWebFeedSelection(_: TimelineModel, webFeed: WebFeed)
}

class TimelineModel: ObservableObject {
	
	weak var delegate: TimelineModelDelegate?
	
	@Published var timelineItems = [TimelineItem]()
	
	init() {
	}
	
	// MARK: API
	
	func rebuildTimelineItems() {
		
	}
	
}

// MARK: Private
private extension TimelineModel {
	
	
}
