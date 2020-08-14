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
	@Environment(\.presentationMode) var presentationMode
	#if os(iOS)
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	#endif
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
					.onReceive(timelineModel.readFilterAndFeedsPublisher!) { (_, filtered) in
						isReadFiltered = filtered
					}
					.hidden(isReadFiltered == nil)
					.help(isReadFiltered ?? false ? "Show Read Articles" : "Filter Read Articles")
				}
				
				ToolbarItem(placement: .bottomBar) {
					Button {
						sceneModel.markAllAsRead()
						#if os(iOS)
						if horizontalSizeClass == .compact {
							presentationMode.wrappedValue.dismiss()
						}
						#endif
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
	}
	
}
