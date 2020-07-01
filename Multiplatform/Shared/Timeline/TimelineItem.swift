//
//  TimelineItem.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/30/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Articles

struct TimelineItem: Identifiable {
	
	var article: Article
	
	var id: String {
		return article.articleID
	}
	
}
