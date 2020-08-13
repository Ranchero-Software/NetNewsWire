//
//  TimelineItemStatusView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 7/1/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct TimelineItemStatusView: View {
	
	var selected: Bool
	var status: TimelineItemStatus
	
	var statusView: some View {
		ZStack {
			Spacer().frame(width: 12)
			switch status {
			case .showUnread:
				if selected {
					AppAssets.timelineUnreadSelected
						.resizable()
						.frame(width: 8, height: 8, alignment: .center)
						.padding(.all, 2)
				} else {
					AppAssets.timelineUnread
						.resizable()
						.frame(width: 8, height: 8, alignment: .center)
						.padding(.all, 2)
				}
			case .showStar:
				AppAssets.timelineStarred
					.resizable()
					.frame(width: 10, height: 10, alignment: .center)
			case .showNone:
				AppAssets.timelineUnread
					.resizable()
					.frame(width: 8, height: 8, alignment: .center)
					.padding(.all, 2)
					.opacity(0)
			}
		}
	}
	
    var body: some View {
		statusView
			.padding(.top, 4)
			.padding(.leading, 4)
    }
	
}
