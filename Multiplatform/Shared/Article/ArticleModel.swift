//
//  ArticleModel.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 7/2/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation

import Foundation
import RSCore
import Account
import Articles

protocol ArticleModelDelegate: class {
	func timelineRequestedWebFeedSelection(_: TimelineModel, webFeed: WebFeed)
}

class ArticleModel: ObservableObject {
	
	weak var delegate: ArticleModelDelegate?
	
}

