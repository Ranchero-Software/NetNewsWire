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
				.environmentObject(sceneNavigationModel)
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
	}

}

struct NavigationView_Previews: PreviewProvider {
    static var previews: some View {
		SceneNavigationView()
			.environmentObject(SceneModel())
    }
}
