//
//  SidebarView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/29/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct SidebarView: View {
	
	// I had to comment out SceneStorage because it blows up if used on macOS
//	@SceneStorage("expandedContainers") private var expandedContainerData = Data()
	@StateObject private var expandedContainers = SidebarExpandedContainers()
	@EnvironmentObject private var sidebarModel: SidebarModel
	
//	@State private var selected = Set<FeedIdentifier>()

	var body: some View {
		List() {
			ForEach(sidebarModel.sidebarItems) { sidebarItem in
				if let containerID = sidebarItem.containerID {
					DisclosureGroup(isExpanded: $expandedContainers[containerID]) {
						ForEach(sidebarItem.children) { sidebarItem in
							if let containerID = sidebarItem.containerID {
								DisclosureGroup(isExpanded: $expandedContainers[containerID]) {
									ForEach(sidebarItem.children) { sidebarItem in
										SidebarItemView(sidebarItem: sidebarItem)
									}
								} label: {
									SidebarItemView(sidebarItem: sidebarItem)
								}
							} else {
								SidebarItemView(sidebarItem: sidebarItem)
							}
						}
					} label: {
						SidebarItemView(sidebarItem: sidebarItem)
					}
				}
			}
		}
//		.onAppear {
//			expandedContainers.data = expandedContainerData
//		}
//		.onReceive(expandedContainers.objectDidChange) {
//			expandedContainerData = expandedContainers.data
//		}
	}
}
