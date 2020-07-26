//
//  TimelineToolbarModifier.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 7/5/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct TimelineToolbarModifier: ViewModifier {
	
	@EnvironmentObject private var sceneModel: SceneModel
	@EnvironmentObject private var timelineModel: TimelineModel
	@State private var isReadFiltered: Bool? = nil
	
	func body(content: Content) -> some View {
		content
			.toolbar {
				#if os(iOS)
				ToolbarItem(placement: .primaryAction) {
					Button {
						if let filter = isReadFiltered {
							timelineModel.changeReadFilterSubject.send(!filter)
						}
					} label: {
						if isReadFiltered ?? false {
							AppAssets.filterActiveImage.font(.title3)
						} else {
							AppAssets.filterInactiveImage.font(.title3)
						}
					}
					.hidden(isReadFiltered == nil)
					.help(isReadFiltered ?? false ? "Show Read Articles" : "Filter Read Articles")
				}
				
				ToolbarItem(placement: .bottomBar) {
					Button {
						sceneModel.markAllAsRead()
					} label: {
						AppAssets.markAllAsReadImage
					}
					.disabled(sceneModel.markAllAsReadButtonState == nil)
					.help("Mark All As Read")
				}
				
				ToolbarItem(placement: .bottomBar) {
					Spacer()
				}
				#endif
			}
			.onReceive(timelineModel.readFilterAndFeedsPublisher!) { (_, filtered) in
				isReadFiltered = filtered
			}
	}
	
}
