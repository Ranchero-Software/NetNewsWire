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
	@State private var selectedPane: MacPreferencePane = .general
	#endif
	#if os(iOS)
	@UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
	#endif
	
	@StateObject private var refreshProgress = RefreshProgressModel()
	@StateObject private var defaults = AppDefaults.shared
	
	@SceneBuilder var body: some Scene {
		#if os(macOS)
		WindowGroup {
			SceneNavigationView()
				.frame(minWidth: 600, idealWidth: 1000, maxWidth: .infinity, minHeight: 600, idealHeight: 700, maxHeight: .infinity)
				.onAppear { refreshProgress.startup() }
				.environmentObject(refreshProgress)
				.environmentObject(defaults)
				.preferredColorScheme(AppDefaults.userInterfaceColorScheme)
		}
		.windowToolbarStyle(UnifiedWindowToolbarStyle())
		.commands {
			SidebarCommands()
			CommandGroup(after: .newItem, addition: {
				Button("New Feed", action: {})
					.keyboardShortcut("N")
				Button("New Folder", action: {})
					.keyboardShortcut("N", modifiers: [.shift, .command])
				Button("Refresh", action: {})
					.keyboardShortcut("R")
			})
			CommandMenu("Subscriptions", content: {
				Button("Import Subscriptions", action: {})
					.keyboardShortcut("I", modifiers: [.shift, .command])
				Button("Import NNW 3 Subscriptions", action: {})
					.keyboardShortcut("O", modifiers: [.shift, .command])
				Button("Export Subscriptions", action: {})
					.keyboardShortcut("E", modifiers: [.shift, .command])
			})
			CommandMenu("Go", content: {
				Button("Next Unread", action: {})
					.keyboardShortcut("/", modifiers: [.command])
				Button("Today", action: {})
					.keyboardShortcut("1", modifiers: [.command])
				Button("All Unread", action: {})
					.keyboardShortcut("2", modifiers: [.command])
				Button("Starred", action: {})
					.keyboardShortcut("3", modifiers: [.command])
			})
			CommandMenu("Article", content: {
				Button("Mark as Read", action: {})
					.keyboardShortcut("U", modifiers: [.shift, .command])
				Button("Mark All as Read", action: {})
					.keyboardShortcut("K", modifiers: [.command])
				Button("Mark Older as Read", action: {})
					.keyboardShortcut("K", modifiers: [.shift, .command])
				Button("Mark as Starred", action: {})
					.keyboardShortcut("L", modifiers: [.shift, .command])
				Button("Open in Browser", action: {})
					.keyboardShortcut(.rightArrow, modifiers: [.command])
			})
			CommandGroup(after: .help, addition: {
				Button("Release Notes", action: {
					NSWorkspace.shared.open(URL.releaseNotes)
				})
				.keyboardShortcut("V", modifiers: [.shift, .command])
			})
		}
		
		// Mac Preferences
		Settings {
			TabView(selection: $selectedPane) {
				GeneralPreferencesView()
					.tabItem {
						Image(systemName: "gearshape")
							.font(.title2)
						Text("General")
					}
					.tag(MacPreferencePane.general)
				
				AccountsPreferencesView()
					.tabItem {
						Image(systemName: "at")
							.font(.title2)
						Text("Accounts")
					}
					.tag(MacPreferencePane.accounts)
				
				LayoutPreferencesView()
					.tabItem {
						Image(systemName: "eyeglasses")
							.font(.title2)
						Text("Viewing")
					}
					.tag(MacPreferencePane.viewing)
				
				AdvancedPreferencesView()
					.tabItem {
						Image(systemName: "scale.3d")
							.font(.title2)
						Text("Advanced")
					}
					.tag(MacPreferencePane.advanced)
			}
			.preferredColorScheme(AppDefaults.userInterfaceColorScheme)
			.frame(width: 500)
			.padding()
		}
		#endif
		
		#if os(iOS)
		WindowGroup {
			SceneNavigationView()
				.onAppear { refreshProgress.startup() }
				.environmentObject(refreshProgress)
				.environmentObject(defaults)
				.preferredColorScheme(AppDefaults.userInterfaceColorScheme)
		}
		#endif
	}
}
