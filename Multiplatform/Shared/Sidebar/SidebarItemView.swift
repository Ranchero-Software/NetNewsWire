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
				HStack {
					Text("Mark All As Read in \(sidebarItem.nameForDisplay)")
					Spacer()
					AppAssets.markAllAsReadImage
						.resizable()
						.aspectRatio(contentMode: .fit)
				}
			}
		}
		if sidebarItem.representedType == .feed {
			Button(action: {}) {
				HStack {
					Text("Mark All as Read")
					Spacer()
					AppAssets.markAllAsReadImage
						.resizable()
						.aspectRatio(contentMode: .fit)
				}
			}
			Divider()
			Button(action: {
				
			}) {
				HStack {
					Text("Open Home Page")
					Spacer()
					AppAssets.openInBrowserImage
				}
			}
			Divider()
			Button(action: {}) {
				HStack {
					Text("Copy Feed URL")
					Spacer()
					AppAssets.copyImage
				}
			}
			Button(action: {}) {
				HStack {
					Text("Copy Home Page URL")
					Spacer()
					AppAssets.copyImage
				}
			}
			Divider()
			Button(action: {}) {
				HStack {
					Text("Rename")
					Spacer()
					AppAssets.renameImage
				}
			}
			Button(action: {}) {
				HStack {
					Text("Delete").foregroundColor(.red)
					Spacer()
					AppAssets.deleteImage.foregroundColor(.red)
				}
			}
		}
		if sidebarItem.representedType == .pseudoFeed {
			Button(action: {}) {
				HStack {
					Text("Mark All as Read")
					Spacer()
					AppAssets.markAllAsReadImage
						.resizable()
						.aspectRatio(contentMode: .fit)
				}
			}
		}
	}
}
