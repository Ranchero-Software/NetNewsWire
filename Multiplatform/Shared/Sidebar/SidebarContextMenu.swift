//
//  SidebarContextMenu.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 7/17/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct SidebarContextMenu: View {
	
	var sidebarItem: SidebarItem
	
    @ViewBuilder var body: some View {
		
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
