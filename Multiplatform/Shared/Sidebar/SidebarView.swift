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
	
	@Binding var sidebarItems: [SidebarItem]
	
	@EnvironmentObject private var refreshProgress: RefreshProgressModel
	@EnvironmentObject private var sceneModel: SceneModel
	@EnvironmentObject private var sidebarModel: SidebarModel

	// I had to comment out SceneStorage because it blows up if used on macOS
	//	@SceneStorage("expandedContainers") private var expandedContainerData = Data()

	private let threshold: CGFloat = 80
	@State private var previousScrollOffset: CGFloat = 0
	@State private var scrollOffset: CGFloat = 0
	@State var pulling: Bool = false
	@State var refreshing: Bool = false

	var body: some View {
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
			List(selection: $sidebarModel.selectedFeedIdentifiers) {
				rows
			}
			if case .refreshProgress(let percent) = refreshProgress.state {
				HStack(alignment: .center) {
					Spacer()
					ProgressView(value: percent).frame(width: 100)
					Spacer()
				}
				.padding(8)
				.background(Color(NSColor.windowBackgroundColor))
				.frame(height: 30)
				.animation(.easeInOut(duration: 0.5))
				.transition(.move(edge: .bottom))
			}
		}
		.alert(isPresented: $sidebarModel.showDeleteConfirmation, content: {
			Alert(title: sidebarModel.countOfFeedsToDelete() > 1 ?
							(Text("Delete multiple items?")) :
							(Text("Delete \(sidebarModel.namesOfFeedsToDelete())?")),
						 message: Text("Are you sure you wish to delete \(sidebarModel.namesOfFeedsToDelete())?"),
				  primaryButton: .destructive(Text("Delete"),
											  action: {
												sidebarModel.deleteFromAccount.send(sidebarModel.sidebarItemToDelete!)
												sidebarModel.sidebarItemToDelete = nil
												sidebarModel.selectedFeedIdentifiers.removeAll()
												sidebarModel.showDeleteConfirmation = false
				  }),
				  secondaryButton: .cancel(Text("Cancel"), action: {
						sidebarModel.sidebarItemToDelete = nil
						sidebarModel.showDeleteConfirmation = false
				  }))
		})
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
			if pulling {
				ProgressView().offset(y: -40)
			}
		}
		.alert(isPresented: $sidebarModel.showDeleteConfirmation, content: {
			Alert(title: sidebarModel.countOfFeedsToDelete() > 1 ?
							(Text("Delete multiple items?")) :
							(Text("Delete \(sidebarModel.namesOfFeedsToDelete())?")),
						 message: Text("Are you sure you wish to delete \(sidebarModel.namesOfFeedsToDelete())?"),
				  primaryButton: .destructive(Text("Delete"),
											  action: {
												sidebarModel.deleteFromAccount.send(sidebarModel.sidebarItemToDelete!)
												sidebarModel.sidebarItemToDelete = nil
												sidebarModel.selectedFeedIdentifiers.removeAll()
												sidebarModel.showDeleteConfirmation = false
				  }),
				  secondaryButton: .cancel(Text("Cancel"), action: {
						sidebarModel.sidebarItemToDelete = nil
						sidebarModel.showDeleteConfirmation = false
				  }))
		})
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
			if !pulling && (scrollOffset > threshold && previousScrollOffset <= threshold) {
				pulling = true
				AccountManager.shared.refreshAll()
			}

			// Crossing the threshold on the way UP, we end the refresh
			if pulling && previousScrollOffset > threshold && scrollOffset <= threshold {
				pulling = false
			}
			
			// Update last scroll offset
			self.previousScrollOffset = self.scrollOffset
		}
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
		ForEach(sidebarItems) { sidebarItem in
			if let containerID = sidebarItem.containerID {
				DisclosureGroup(isExpanded: $sidebarModel.expandedContainers[containerID]) {
					ForEach(sidebarItem.children) { sidebarItem in
						if let containerID = sidebarItem.containerID {
							DisclosureGroup(isExpanded: $sidebarModel.expandedContainers[containerID]) {
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
					SidebarItemView(sidebarItem: sidebarItem)
						.padding(.leading, 4)
						.environmentObject(sidebarModel)
					#else
					if sidebarItem.representedType == .smartFeedController {
						GeometryReader { proxy in
							SidebarItemView(sidebarItem: sidebarItem)
								.preference(key: RefreshKeyTypes.PrefKey.self, value: [RefreshKeyTypes.PrefData(vType: .movingView, bounds: proxy.frame(in: .global))])
								.environmentObject(sidebarModel)
						}
					} else {
						SidebarItemView(sidebarItem: sidebarItem)
							.environmentObject(sidebarModel)
					}
					#endif
				}
			}
		}
	}

	struct SidebarItemNavigation: View {
		
		@EnvironmentObject private var sidebarModel: SidebarModel
		var sidebarItem: SidebarItem
		
		var body: some View {
			#if os(macOS)
			SidebarItemView(sidebarItem: sidebarItem)
				.tag(sidebarItem.feed!.feedID!)
			#else
			ZStack {
				SidebarItemView(sidebarItem: sidebarItem)
				NavigationLink(destination: TimelineContainerView(),
							   tag: sidebarItem.feed!.feedID!,
							   selection: $sidebarModel.selectedFeedIdentifier) {
					EmptyView()
				}.buttonStyle(PlainButtonStyle())
			}
			#endif
		}
		
	}
	
}
