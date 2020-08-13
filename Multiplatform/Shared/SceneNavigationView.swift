//
//  SceneNavigationView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/28/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
#if os(macOS)
import AppKit
#endif


struct SceneNavigationView: View {

	@StateObject private var sceneModel = SceneModel()
	@StateObject private var sceneNavigationModel = SceneNavigationModel()
	
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
				TimelineContainerView()
			}
			#else
			TimelineContainerView()
			#endif

			ArticleContainerView()
		}
		.environmentObject(sceneModel)
		.onAppear {
			sceneModel.startup()
		}
		.onReceive(sceneModel.$accountSyncErrors) { errors in
			if errors.count == 0 {
				sceneNavigationModel.showAccountSyncErrorAlert = false
			} else {
				if errors.count > 1 {
					sceneNavigationModel.showAccountSyncErrorAlert = true
				} else {
					sceneNavigationModel.sheetToShow = .fixCredentials
				}
			}
		}
		.sheet(isPresented: $sceneNavigationModel.showSheet,
			   onDismiss: {
				sceneNavigationModel.sheetToShow = .none
				sceneModel.accountSyncErrors = []
			   }) {
					if sceneNavigationModel.sheetToShow == .web {
						AddWebFeedView(isPresented: $sceneNavigationModel.showSheet)
					}
					if sceneNavigationModel.sheetToShow == .folder {
						AddFolderView(isPresented: $sceneNavigationModel.showSheet)
					}
					#if os(iOS)
					if sceneNavigationModel.sheetToShow == .settings {
						SettingsView()
					}
					#endif
					if sceneNavigationModel.sheetToShow == .fixCredentials {
						FixAccountCredentialView(accountSyncError: sceneModel.accountSyncErrors[0])
					}
		}
		.alert(isPresented: $sceneNavigationModel.showAccountSyncErrorAlert, content: {
			#if os(macOS)
			return Alert(title: Text("Account Sync Error"),
						 message: Text("The following accounts failed to sync: ") + Text(sceneModel.accountSyncErrors.map({ $0.account.nameForDisplay }).joined(separator: ", ")) + Text(". You can update credentials in Preferences"),
						 dismissButton: .default(Text("Dismiss")))
			#else
			return Alert(title: Text("Account Sync Error"),
				  message: Text("The following accounts failed to sync: ") + Text(sceneModel.accountSyncErrors.map({ $0.account.nameForDisplay }).joined(separator: ", ")) + Text(". You can update credentials in Settings"),
				  primaryButton: .default(Text("Show Settings"), action: {
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
						sceneNavigationModel.sheetToShow = .settings
					})
					
				  }),
				  secondaryButton: .cancel(Text("Dismiss")))
			
			#endif
		})
		.toolbar {
			
			#if os(macOS)
			ToolbarItem(placement: .navigation) {
				Button {
					NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
				} label: {
					AppAssets.sidebarToggleImage
				}
				.help("Toggle Sidebar")
			}
			ToolbarItem() {
				Menu {
					Button("Add Web Feed", action: { sceneNavigationModel.sheetToShow = .web })
					Button("Add Reddit Feed", action:  { })
					Button("Add Twitter Feed", action:  { })
					Button("Add Folder", action:  { sceneNavigationModel.sheetToShow = .folder})
				} label : {
					AppAssets.addMenuImage
				}
			}
			ToolbarItem {
				Button {
					AccountManager.shared.refreshAll(completion: nil)
					
				} label: {
					AppAssets.refreshImage
				}
				.help("Refresh").padding(.trailing, 40)
			}
			ToolbarItem {
				Button {
					sceneModel.markAllAsRead()
				} label: {
					AppAssets.markAllAsReadImagePNG
						.offset(y: 7)
				}
				.disabled(sceneModel.markAllAsReadButtonState == nil)
				.help("Mark All as Read")
			}
//			ToolbarItem {
//				MacSearchField()
//					.frame(width: 200)
//			}
			ToolbarItem {
				Button {
					sceneModel.goToNextUnread()
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
					sceneModel.openSelectedArticleInBrowser()
				} label: {
					AppAssets.openInBrowserImage
				}
				.disabled(sceneModel.openInBrowserButtonState == nil)
				.help("Open in Browser")
			}
			ToolbarItem {
				ZStack {
					if sceneNavigationModel.showShareSheet {
						SharingServiceView(articles: sceneModel.selectedArticles, showing: $sceneNavigationModel.showShareSheet)
							.frame(width: 20, height: 20)
					}
					Button {
						sceneNavigationModel.showShareSheet = true
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
