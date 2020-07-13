//
//  SidebarItemView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/29/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct SidebarItemView: View {
	
	@StateObject var feedIconImageLoader = FeedIconImageLoader()
	var sidebarItem: SidebarItem
	
    var body: some View {
		HStack {
			if let image = feedIconImageLoader.image {
				IconImageView(iconImage: image)
					.frame(width: 20, height: 20, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
			}
			Text(verbatim: sidebarItem.nameForDisplay)
			Spacer()
			if sidebarItem.unreadCount > 0 {
				UnreadCountView(count: sidebarItem.unreadCount)
			}
			#if os(iOS)
			if sidebarItem.representedType == .webFeed || sidebarItem.representedType == .pseudoFeed {
				Spacer()
					.frame(width: 16)
			}
			#endif
		}
		.onAppear {
			if let feed = sidebarItem.feed {
				feedIconImageLoader.loadImage(for: feed)
			}
		}.contextMenu(menuItems: {
			menuItems
		})
    }
	
	@ViewBuilder var menuItems: some View {
		if sidebarItem.representedType == .account {
			Button(action: {}) {
				Text("Get Info")
				#if os(iOS)
				AppAssets.getInfoImage
				#endif
			}
			Button(action: {}) {
				Text("Mark All As Read")
				#if os(iOS)
				AppAssets.markAllAsReadImage
				#endif
			}
		}
		
		if sidebarItem.representedType == .pseudoFeed {
			Button(action: {}) {
				Text("Mark All As Read")
				#if os(iOS)
				AppAssets.markAllAsReadImage
				#endif
			}
		}
		
		if sidebarItem.representedType == .webFeed {
			Button(action: {}) {
				Text("Get Info")
				#if os(iOS)
				AppAssets.getInfoImage
				#endif
			}
			Button(action: {}) {
				Text("Mark All As Read")
				#if os(iOS)
				AppAssets.markAllAsReadImage
				#endif
			}
			Divider()
			Button(action: {}) {
				Text("Open Home Page")
				#if os(iOS)
				AppAssets.openInBrowserImage
				#endif
			}
			Divider()
			Button(action: {}) {
				Text("Copy Feed URL")
				#if os(iOS)
				AppAssets.copyImage
				#endif
			}
			Button(action: {}) {
				Text("Copy Home Page URL")
				#if os(iOS)
				AppAssets.copyImage
				#endif
			}
			Divider()
			Button(action: {}) {
				Text("Rename")
				#if os(iOS)
				AppAssets.renameImage
				#endif
			}
			Button(action: {}) {
				Text("Delete")
				#if os(iOS)
				AppAssets.deleteImage
				#endif
			}
		}
		
		if sidebarItem.representedType == .folder {
			Button(action: {}) {
				Text("Mark All As Read")
				#if os(iOS)
				AppAssets.markAllAsReadImage
				#endif
			}
			Divider()
			Button(action: {}) {
				Text("Rename")
				#if os(iOS)
				AppAssets.renameImage
				#endif
			}
			Button(action: {}) {
				Text("Delete")
				#if os(iOS)
				AppAssets.deleteImage
				#endif
			}
		}
	}
}
