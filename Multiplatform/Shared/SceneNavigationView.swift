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
	@State private var showSheet = false
	@State private var showShareSheet = false
	@State private var sheetToShow: ToolbarSheets = .none
	
	#if os(iOS)
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
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
				Button {
				} label: {
					AppAssets.refreshImage
				}
				.help("Refresh").padding(.trailing, 40)
			}
			ToolbarItem {
				Button {
				} label: {
					AppAssets.markAllAsReadImagePDF
						.resizable()
						.scaledToFit()
						.frame(width: 20, height: 20, alignment: .center)
				}
				.disabled(sceneModel.markAllAsReadButtonState == nil)
				.help("Mark All as Read")
			}
			ToolbarItem {
				MacSearchField()
					.frame(width: 200)
			}
			ToolbarItem {
				Button {
				} label: {
					AppAssets.nextUnreadArticleImage
				}
				.disabled(sceneModel.nextUnreadButtonState == nil)
				.help("Go to Next Unread").padding(.trailing, 40)
			}
			ToolbarItem {
				Button {
					sceneModel.toggleReadStatusForSelectedArticles()
				} label: {
					if sceneModel.readButtonState ?? false {
						AppAssets.readClosedImage
					} else {
						AppAssets.readOpenImage
					}
				}
				.disabled(sceneModel.readButtonState == nil)
				.help(sceneModel.readButtonState ?? false ? "Mark as Unread" : "Mark as Read")
			}
			ToolbarItem {
				Button {
					sceneModel.toggleStarredStatusForSelectedArticles()
				} label: {
					if sceneModel.starButtonState ?? false {
						AppAssets.starClosedImage
					} else {
						AppAssets.starOpenImage
					}
				}
				.disabled(sceneModel.starButtonState == nil)
				.help(sceneModel.starButtonState ?? false ? "Mark as Unstarred" : "Mark as Starred")
			}
			ToolbarItem {
				Button {
				} label: {
					AppAssets.articleExtractorOff
				}
				.disabled(sceneModel.extractorButtonState == nil)
				.help("Show Reader View")
			}
			ToolbarItem {
				Button {
				} label: {
					AppAssets.openInBrowserImage
				}
				.disabled(sceneModel.openInBrowserButtonState == nil)
				.help("Open in Browser")
			}
			ToolbarItem {
				ZStack {
					if showShareSheet {
						SharingServiceView(articles: sceneModel.selectedArticles, showing: $showShareSheet)
							.frame(width: 20, height: 20)
					}
					Button {
						showShareSheet = true
					} label: {
						AppAssets.shareImage
					}
				}
				.disabled(sceneModel.shareButtonState == nil)
				.help("Share")
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
