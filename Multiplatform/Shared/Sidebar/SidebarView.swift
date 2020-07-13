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
	@State var navigate = false

	@ViewBuilder var body: some View {
		#if os(macOS)
		VStack {
			HStack {
				Spacer()
				Button (action: {
					withAnimation {
						sidebarModel.isReadFiltered.toggle()
					}
				}, label: {
					if sidebarModel.isReadFiltered {
						AppAssets.filterActiveImage
					} else {
						AppAssets.filterInactiveImage
					}
				})
				.padding(.top, 8).padding(.trailing)
				.buttonStyle(PlainButtonStyle())
				.help(sidebarModel.isReadFiltered ? "Show Read Feeds" : "Filter Read Feeds")
			}
			ZStack {
				NavigationLink(destination: TimelineContainerView(feeds: sidebarModel.selectedFeeds), isActive: $navigate) {
					EmptyView()
				}.hidden()
				List(selection: $sidebarModel.selectedFeedIdentifiers) {
					rows
				}
			}
			.onChange(of: sidebarModel.selectedFeedIdentifiers) { value in
				navigate = !sidebarModel.selectedFeedIdentifiers.isEmpty
			}
		}
		#else
		List {
			rows
		}
		.navigationTitle(Text("Feeds"))
		#endif
//		.onAppear {
//			expandedContainers.data = expandedContainerData
//		}
//		.onReceive(expandedContainers.objectDidChange) {
//			expandedContainerData = expandedContainers.data
//		}
	}
	
	var rows: some View {
		ForEach(sidebarModel.sidebarItems) { sidebarItem in
			if let containerID = sidebarItem.containerID {
				DisclosureGroup(isExpanded: $expandedContainers[containerID]) {
					ForEach(sidebarItem.children) { sidebarItem in
						if let containerID = sidebarItem.containerID {
							DisclosureGroup(isExpanded: $expandedContainers[containerID]) {
								ForEach(sidebarItem.children) { sidebarItem in
									buildSidebarItemNavigation(sidebarItem)
								}
							} label: {
								buildSidebarItemNavigation(sidebarItem)
							}
						} else {
							buildSidebarItemNavigation(sidebarItem)
						}
					}
				} label: {
					#if os(macOS)
					SidebarItemView(sidebarItem: sidebarItem).padding(.leading, 4)
					#else
					SidebarItemView(sidebarItem: sidebarItem)
					#endif
				}
			}
		}
	}
	
	func buildSidebarItemNavigation(_ sidebarItem: SidebarItem) -> some View {
		#if os(macOS)
		return SidebarItemView(sidebarItem: sidebarItem).tag(sidebarItem.feed!.feedID!)
		#else
		return ZStack {
			SidebarItemView(sidebarItem: sidebarItem)
			NavigationLink(destination: TimelineContainerView(feeds: sidebarModel.selectedFeeds),
						   tag: sidebarItem.feed!.feedID!,
						   selection: $sidebarModel.selectedFeedIdentifier) {
				EmptyView()
			}.buttonStyle(PlainButtonStyle())
		}
		#endif
	}
	
}
