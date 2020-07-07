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
	
	@StateObject private var defaults = AppDefaults.shared

	@SceneBuilder var body: some Scene {
		#if os(macOS)
		WindowGroup {
			SceneNavigationView()
				.frame(minWidth: 600, idealWidth: 1000, maxWidth: .infinity, minHeight: 600, idealHeight: 700, maxHeight: .infinity)
				.environmentObject(defaults)
		}
		.windowToolbarStyle(UnifiedWindowToolbarStyle())
		.commands {
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
		}
		
		// Mac Preferences
		Settings {
			MacPreferencesView()
			.padding()
			.frame(width: 500)
			.navigationTitle("Preferences")
			.environmentObject(defaults)
		}
		.windowToolbarStyle(UnifiedWindowToolbarStyle())
		
		#endif
		
		#if os(iOS)
		WindowGroup {
			SceneNavigationView()
				.environmentObject(defaults)
				.modifier(PreferredColorSchemeModifier(preferredColorScheme: defaults.userInterfaceColorPalette))
		}
		.commands {
			CommandGroup(after: .newItem, addition: {
				Button("New Feed", action: {})
					.keyboardShortcut("N")
				Button("New Folder", action: {})
					.keyboardShortcut("N", modifiers: [.shift, .command])
				Button("Refresh", action: {})
					.keyboardShortcut("R")
			})
			CommandGroup(before: .sidebar, addition: {
				Button("Show Sidebar", action: {})
					.keyboardShortcut("S", modifiers: [.control, .command])
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
		}
		#endif
	}
}
