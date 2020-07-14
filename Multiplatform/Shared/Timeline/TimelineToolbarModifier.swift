//
//  TimelineToolbarModifier.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 7/5/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct TimelineToolbarModifier: ViewModifier {
	
	@EnvironmentObject private var timelineModel: TimelineModel

	func body(content: Content) -> some View {
		content
			.toolbar {
				#if os(iOS)
				ToolbarItem(placement: .navigation) {
					Button {
						withAnimation {
							timelineModel.toggleReadFilter()
						}
					} label: {
						if timelineModel.isReadFiltered ?? false {
							AppAssets.filterActiveImage.font(.title3)
						} else {
							AppAssets.filterInactiveImage.font(.title3)
						}
					}
					.hidden(timelineModel.isReadFiltered == nil)
					.help(timelineModel.isReadFiltered ?? false ? "Show Read Articles" : "Filter Read Articles")
				}
				
				ToolbarItem {
					Button {
					} label: {
						AppAssets.markAllAsReadImage
					}
					.help("Mark All As Read")
				}
				
				ToolbarItem {
					Spacer()
				}
				
				ToolbarItem(placement: .automatic) {
					RefreshProgressView()
				}
				
				ToolbarItem {
					Spacer()
				}
				
				ToolbarItem {
					Button {
					} label: {
						AppAssets.nextUnreadArticleImage.font(.title3)
					}
					.help("Next Unread")
				}
				
				#endif
			}
	}
	
}
