//
//  MainApp.swift
//  Shared
//
//  Created by Maurice Parker on 6/27/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

@main
struct MainApp: App {
	
	#if os(macOS)
	@NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
	#endif
	#if os(iOS)
	@UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
	#endif
	
	@StateObject private var sceneModel = SceneModel()
	
    var body: some Scene {
        WindowGroup {
			#if os(macOS)
			SceneNavigationView()
				.frame(minWidth: 600, idealWidth: 1000, maxWidth: .infinity, minHeight: 600, idealHeight: 700, maxHeight: .infinity)
				.environmentObject(sceneModel)
			#endif
			
			#if os(iOS)
			SceneNavigationView()
				.environmentObject(sceneModel)
			#endif
        }
    }
	
}
