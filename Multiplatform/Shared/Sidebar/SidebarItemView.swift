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
	
	@StateObject var feedImageLoader = FeedImageLoader()
	var sidebarItem: SidebarItem
	
    var body: some View {
		HStack {
			if let image = feedImageLoader.image {
				IconImageView(iconImage: image)
			}
			Text(verbatim: sidebarItem.nameForDisplay)
			Spacer()
			if sidebarItem.unreadCount > 0 {
				UnreadCountView(count: sidebarItem.unreadCount)
			}
		}
		.onAppear {
			if let feed = sidebarItem.feed {
				feedImageLoader.loadImage(for: feed)
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
					Image("markAllAsRead")
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
					Image("markAllAsRead")
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
					Image(systemName: "safari")
				}
			}
			Divider()
			Button(action: {}) {
				HStack {
					Text("Copy Feed URL")
					Spacer()
					Image(systemName: "doc.on.doc")
				}
			}
			Button(action: {}) {
				HStack {
					Text("Copy Home Page URL")
					Spacer()
					Image(systemName: "doc.on.doc")
				}
			}
			Divider()
			Button(action: {}) {
				HStack {
					Text("Rename")
					Spacer()
					Image(systemName: "textformat")
				}
			}
			Button(action: {}) {
				HStack {
					Text("Delete").foregroundColor(.red)
					Spacer()
					Image(systemName: "trash").foregroundColor(.red)
				}
			}
		}
		if sidebarItem.representedType == .pseudoFeed {
			Button(action: {}) {
				HStack {
					Text("Mark All as Read")
					Spacer()
					Image("markAllAsRead")
						.resizable()
						.aspectRatio(contentMode: .fit)
				}
			}
		}
	}
}
