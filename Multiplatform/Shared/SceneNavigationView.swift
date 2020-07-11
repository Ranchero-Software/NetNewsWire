//
//  SceneNavigationView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/28/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct SceneNavigationView: View {

	@StateObject private var sceneModel = SceneModel()
	@State private var showSheet: Bool = false
	@State private var sheetToShow: ToolbarSheets = .none
	
	#if os(iOS)
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	@Environment(\.scenePhase) private var scenePhase
	#endif
	
	var body: some View {
		NavigationView {
			#if os(macOS)
			SidebarContainerView()
				.frame(minWidth: 100, idealWidth: 150, maxHeight: .infinity)
			#else
				SidebarContainerView()
			#endif

			#if os(iOS)
			if horizontalSizeClass != .compact {
				Text("Timeline")
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			}
			#else
			Text("Timeline")
				.frame(maxWidth: .infinity, maxHeight: .infinity)
			#endif

			#if os(macOS)
			Text("None Selected")
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.toolbar { Spacer() }
			#else
			Text("None Selected")
				.frame(maxWidth: .infinity, maxHeight: .infinity)
			#endif
		}
		.environmentObject(sceneModel)
		.onAppear {
			sceneModel.startup()
		}
		.sheet(isPresented: $showSheet, onDismiss: { sheetToShow = .none }) {
			
			if sheetToShow == .web {
				AddWebFeedView()
			}
			if sheetToShow == .folder {
				AddFolderView()
			}
		}
		.onChange(of: sheetToShow) { value in
			value != .none ? (showSheet = true) : (showSheet = false)
		}
		.onChange(of: scenePhase) { newPhase in
			if newPhase == .background {
				#if os(iOS)
				WidgetDataEncoder.encodeWidgetData()
				#endif
			}
		}
		.toolbar {
			
			#if os(macOS)
			ToolbarItem() {
				Menu {
					Button("Add Web Feed", action: { sheetToShow = .web })
					Button("Add Reddit Feed", action:  { })
					Button("Add Twitter Feed", action:  { })
					Button("Add Folder", action:  { sheetToShow = .folder})
				} label : {
					AppAssets.addMenuImage
				}
			}
			ToolbarItem {
				Button(action: {}, label: {
					AppAssets.refreshImage
				}).help("Refresh").padding(.trailing, 40)
			}
			ToolbarItem {
				Button(action: {}, label: {
					AppAssets.markAllAsReadImagePDF
						.resizable()
						.scaledToFit()
						.frame(width: 20, height: 20, alignment: .center)
				}).help("Mark All as Read")
			}
			ToolbarItem {
				MacSearchField()
					.frame(width: 200)
			}
			ToolbarItem {
				Button(action: {}, label: {
					AppAssets.nextUnreadArticleImage
				}).help("Go to Next Unread").padding(.trailing, 40)
			}
			ToolbarItem {
				Button(action: {}, label: {
					AppAssets.starOpenImage
				}).help("Mark as Starred")
			}
			ToolbarItem {
				Button(action: {}, label: {
					AppAssets.readClosedImage
				}).help("Mark as Unread")
			}
			ToolbarItem {
				Button(action: {}, label: {
					AppAssets.articleExtractorOff
				}).help("Show Reader View")
			}
			ToolbarItem {
				Button(action: {}, label: {
					AppAssets.openInBrowserImage
				}).help("Open in Browser")
			}
			ToolbarItem {
				Button(action: {}, label: {
					AppAssets.shareImage
				}).help("Share")
			}
			#endif
		}
	}
}

struct NavigationView_Previews: PreviewProvider {
    static var previews: some View {
		SceneNavigationView()
			.environmentObject(SceneModel())
    }
}
