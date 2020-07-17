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
			SidebarContextMenu(sidebarItem: sidebarItem)
		})
    }
	
}
