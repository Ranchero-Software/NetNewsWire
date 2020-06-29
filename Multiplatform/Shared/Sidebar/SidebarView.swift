//
//  SidebarView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/29/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct SidebarView: View {
	
	@EnvironmentObject private var sidebarModel: SidebarModel
	
	var body: some View {
		List {
			ForEach(sidebarModel.sidebarItems) { section in
				OutlineGroup(sidebarModel.sidebarItems, children: \.children) { sidebarItem in
					Text(sidebarItem.nameForDisplay)
				}
			}
		}
	}
	
}
