//
//  NetNewsWire.swift
//  Shared
//
//  Created by Maurice Parker on 6/27/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

@main
struct NetNewsWire: App {
	
	#if os(macOS)
	@NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
	#endif
	#if os(iOS)
	@UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
	#endif
	
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
