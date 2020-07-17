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
			Button {
			} label: {
				Text("Get Info")
				#if os(iOS)
				AppAssets.getInfoImage
				#endif
			}
			Button {
			} label: {
				Text("Mark All As Read")
				#if os(iOS)
				AppAssets.markAllAsReadImage
				#endif
			}
		}
		
		if sidebarItem.representedType == .pseudoFeed {
			Button {
			} label: {
				Text("Mark All As Read")
				#if os(iOS)
				AppAssets.markAllAsReadImage
				#endif
			}
		}
		
		if sidebarItem.representedType == .webFeed {
			Button {
			} label: {
				Text("Get Info")
				#if os(iOS)
				AppAssets.getInfoImage
				#endif
			}
			Button {
			} label: {
				Text("Mark All As Read")
				#if os(iOS)
				AppAssets.markAllAsReadImage
				#endif
			}
			Divider()
			Button {
			} label: {
				Text("Open Home Page")
				#if os(iOS)
				AppAssets.openInBrowserImage
				#endif
			}
			Divider()
			Button {
			} label: {
				Text("Copy Feed URL")
				#if os(iOS)
				AppAssets.copyImage
				#endif
			}
			Button {
			} label: {
				Text("Copy Home Page URL")
				#if os(iOS)
				AppAssets.copyImage
				#endif
			}
			Divider()
			Button {
			} label: {
				Text("Rename")
				#if os(iOS)
				AppAssets.renameImage
				#endif
			}
			Button {
			} label: {
				Text("Delete")
				#if os(iOS)
				AppAssets.deleteImage
				#endif
			}
		}
		
		if sidebarItem.representedType == .folder {
			Button {
			} label: {
				Text("Mark All As Read")
				#if os(iOS)
				AppAssets.markAllAsReadImage
				#endif
			}
			Divider()
			Button {
			} label: {
				Text("Rename")
				#if os(iOS)
				AppAssets.renameImage
				#endif
			}
			Button {
			} label: {
				Text("Delete")
				#if os(iOS)
				AppAssets.deleteImage
				#endif
			}
		}
		
    }
}
