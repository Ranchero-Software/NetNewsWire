//
//  TimelineSortOrderView.swift
//  Multiplatform macOS
//
//  Created by Maurice Parker on 7/12/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct TimelineSortOrderView: View {
	
	@EnvironmentObject var settings: AppDefaults
	@State var selection: Int = 1
	
	var body: some View {
		Menu {
			Button {
				settings.timelineSortDirection = true
			} label: {
				HStack {
					Text("Newest to Oldest")
					if settings.timelineSortDirection {
						Spacer()
						AppAssets.checkmarkImage
					}
				}
			}
			Button {
				settings.timelineSortDirection = false
			} label: {
				HStack {
					Text("Oldest to Newest")
					if !settings.timelineSortDirection {
						Spacer()
						AppAssets.checkmarkImage
					}
				}
			}
			Divider()
			Button {
				settings.timelineGroupByFeed.toggle()
			} label: {
				HStack {
					Text("Group by Feed")
					if settings.timelineGroupByFeed {
						Spacer()
						AppAssets.checkmarkImage
					}
				}
			}
		} label : {
			if settings.timelineSortDirection {
				Text("Sort Newest to Oldest")
			} else {
				Text("Sort Oldest to Newest")
			}
		}
		.font(.subheadline)
		.frame(width: 150)
		.padding(.top, 8).padding(.leading)
		.menuStyle(BorderlessButtonMenuStyle())
	}
}
