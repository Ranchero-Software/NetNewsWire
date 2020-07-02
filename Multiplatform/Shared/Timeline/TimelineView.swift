//
//  TimelineView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/30/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct TimelineView: View {
	
	@EnvironmentObject private var timelineModel: TimelineModel

	var body: some View {
		ScrollView {
			LazyVStack() {
				ForEach(timelineModel.timelineItems) { timelineItem in
					TimelineItemView(timelineItem: timelineItem)
				}
			}
		}
    }
	
//	var body: some View {
//		List(timelineModel.timelineItems) { timelineItem in
//			TimelineItemView(timelineItem: timelineItem)
//		}
//	}
	
}
