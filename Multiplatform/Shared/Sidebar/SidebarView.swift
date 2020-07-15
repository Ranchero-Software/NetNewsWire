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

	@State var refreshErrorMessage = ""
	@State var showRefreshError: Bool = false

	private let threshold: CGFloat = 80
	@State private var previousScrollOffset: CGFloat = 0
	@State private var scrollOffset: CGFloat = 0
	@State var refreshing: Bool = false
	
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
		ZStack(alignment: .top) {
			List {
				rows
			}
			.background(RefreshFixedView())
			.navigationTitle(Text("Feeds"))
			.onPreferenceChange(RefreshKeyTypes.PrefKey.self) { values in
				refreshLogic(values: values)
			}
			if refreshing {
				ProgressView().offset(y: -40)
			}
		}
		.alert(isPresented: $showRefreshError) {
			Alert(title: Text("Account Error"), message: Text(verbatim: refreshErrorMessage), dismissButton: .default(Text("OK")))
		}
		#endif
//		.onAppear {
//			expandedContainers.data = expandedContainerData
//		}
//		.onReceive(expandedContainers.objectDidChange) {
//			expandedContainerData = expandedContainers.data
//		}
	}
	
	func refreshLogic(values: [RefreshKeyTypes.PrefData]) {
		DispatchQueue.main.async {
			let movingBounds = values.first { $0.vType == .movingView }?.bounds ?? .zero
			let fixedBounds = values.first { $0.vType == .fixedView }?.bounds ?? .zero
			scrollOffset = movingBounds.minY - fixedBounds.minY

			// Crossing the threshold on the way down, we start the refresh process
			if !refreshing && (scrollOffset > threshold && previousScrollOffset <= threshold) {
				refreshing = true
				AccountManager.shared.refreshAll(errorHandler: handleRefreshError)
			}

			// Crossing the threshold on the way UP, we end the refresh
			if refreshing && previousScrollOffset > threshold && scrollOffset <= threshold {
				refreshing = false
			}
			
			// Update last scroll offset
			self.previousScrollOffset = self.scrollOffset
		}
	}
	
	func handleRefreshError(_ error: Error) {
		refreshErrorMessage = error.localizedDescription
		showRefreshError = true
	}
	
	struct RefreshFixedView: View {
		var body: some View {
			GeometryReader { proxy in
				Color.clear.preference(key: RefreshKeyTypes.PrefKey.self, value: [RefreshKeyTypes.PrefData(vType: .fixedView, bounds: proxy.frame(in: .global))])
			}
		}
	}

	struct RefreshKeyTypes {
		enum ViewType: Int {
			case movingView
			case fixedView
		}

		struct PrefData: Equatable {
			let vType: ViewType
			let bounds: CGRect
		}

		struct PrefKey: PreferenceKey {
			static var defaultValue: [PrefData] = []

			static func reduce(value: inout [PrefData], nextValue: () -> [PrefData]) {
				value.append(contentsOf: nextValue())
			}

			typealias Value = [PrefData]
		}
	}
	
	var rows: some View {
		ForEach(sidebarModel.sidebarItems) { sidebarItem in
			if let containerID = sidebarItem.containerID {
				DisclosureGroup(isExpanded: $expandedContainers[containerID]) {
					ForEach(sidebarItem.children) { sidebarItem in
						if let containerID = sidebarItem.containerID {
							DisclosureGroup(isExpanded: $expandedContainers[containerID]) {
								ForEach(sidebarItem.children) { sidebarItem in
									SidebarItemNavigation(sidebarItem: sidebarItem)
								}
							} label: {
								SidebarItemNavigation(sidebarItem: sidebarItem)
							}
						} else {
							SidebarItemNavigation(sidebarItem: sidebarItem)
						}
					}
				} label: {
					#if os(macOS)
					SidebarItemView(sidebarItem: sidebarItem).padding(.leading, 4)
					#else
					if sidebarItem.representedType == .smartFeedController {
						GeometryReader { proxy in
							SidebarItemView(sidebarItem: sidebarItem)
								.preference(key: RefreshKeyTypes.PrefKey.self, value: [RefreshKeyTypes.PrefData(vType: .movingView, bounds: proxy.frame(in: .global))])
						}
					} else {
						SidebarItemView(sidebarItem: sidebarItem)
					}
					#endif
				}
			}
		}
	}

	struct SidebarItemNavigation: View {
		
		@EnvironmentObject private var sidebarModel: SidebarModel
		var sidebarItem: SidebarItem
		
		@ViewBuilder var body: some View {
			#if os(macOS)
			SidebarItemView(sidebarItem: sidebarItem).tag(sidebarItem.feed!.feedID!)
			#else
			ZStack {
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
	
}
