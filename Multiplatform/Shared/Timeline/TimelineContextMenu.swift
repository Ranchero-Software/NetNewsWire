//
//  TimelineContextMenu.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 7/17/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct TimelineContextMenu: View {
	
	@EnvironmentObject private var timelineModel: TimelineModel
	var timelineItem: TimelineItem

    @ViewBuilder var body: some View {
		
		if timelineModel.canMarkAboveAsRead(timelineItem.article) {
			Button {
				timelineModel.markAboveAsRead(timelineItem.article)
			} label: {
				Text("Mark Above as Read")
				#if os(iOS)
				AppAssets.markAboveAsReadImage
				#endif
			}
		}
		
		if timelineModel.canMarkBelowAsRead(timelineItem.article) {
			Button {
				timelineModel.markBelowAsRead(timelineItem.article)
			} label: {
				Text("Mark Below As Read")
				#if os(iOS)
				AppAssets.markBelowAsReadImage
				#endif
			}
		}
		
	}
}
