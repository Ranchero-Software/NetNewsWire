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
	@EnvironmentObject private var sidebarModel: SidebarModel
	@State private var showInspector: Bool = false
	var sidebarItem: SidebarItem
	
    var body: some View {
		HStack {
			#if os(macOS)
			HStack {
				if let image = feedIconImageLoader.image {
					IconImageView(iconImage: image)
						.frame(width: 20, height: 20, alignment: .center)
				}
				Text(verbatim: sidebarItem.nameForDisplay)
				Spacer()
				if sidebarItem.unreadCount > 0 {
					UnreadCountView(count: sidebarItem.unreadCount)
				}
			}
			#else
			HStack(alignment: .top) {
				if let image = feedIconImageLoader.image {
					IconImageView(iconImage: image)
						.frame(width: 20, height: 20)
				}
				Text(verbatim: sidebarItem.nameForDisplay)
			}
			Spacer()
			if sidebarItem.unreadCount > 0 {
				UnreadCountView(count: sidebarItem.unreadCount)
			}
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
		}.contextMenu {
			SidebarContextMenu(showInspector: $showInspector, sidebarItem: sidebarItem)
				.environmentObject(sidebarModel)
		}
		.sheet(isPresented: $showInspector, onDismiss: { showInspector = false}) {
			InspectorView(sidebarItem: sidebarItem)
		}
    }
	
}
