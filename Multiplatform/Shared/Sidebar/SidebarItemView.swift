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
				Text("Mark All As Read")
				AppAssets.markAllAsReadImage
			}
		}
		
		if sidebarItem.representedType == .pseudoFeed {
			Button(action: {}) {
				Text("Mark All As Read")
				AppAssets.markAllAsReadImage
			}
		}
		
		if sidebarItem.representedType == .webFeed {
			Button(action: {}) {
				Text("Mark All As Read")
				AppAssets.markAllAsReadImage
			}
			Divider()
			Button(action: {
				
			}) {
				Text("Open Home Page")
				AppAssets.openInBrowserImage
			}
			Divider()
			Button(action: {}) {
				Text("Copy Feed URL")
				AppAssets.copyImage
			}
			Button(action: {}) {
				Text("Copy Home Page URL")
				AppAssets.copyImage
			}
			Divider()
			Button(action: {}) {
				Text("Rename")
				AppAssets.renameImage
			}
			Button(action: {}) {
				Text("Delete")
				AppAssets.deleteImage
			}
		}
		
		if sidebarItem.representedType == .folder {
			Button(action: {}) {
				Text("Mark All As Read")
				AppAssets.markAllAsReadImage
			}
			Divider()
			Button(action: {}) {
				Text("Rename")
				AppAssets.renameImage
			}
			Button(action: {}) {
				Text("Delete")
				AppAssets.deleteImage
			}
		}
	}
}
