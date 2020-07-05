//
//  TimeilneToolbarModifier.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 7/5/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation

import SwiftUI

struct TimelineToolbarModifier: ViewModifier {
	
	func body(content: Content) -> some View {
		content
			.toolbar {
				#if os(iOS)
				ToolbarItem {
					Button(action: {
					}, label: {
						AppAssets.markAllAsReadImage
							.foregroundColor(.accentColor)
					}).help("Mark All As Read")
				}
				ToolbarItem {
					Spacer()
				}
				ToolbarItem(placement: .automatic) {
					RefreshProgressView()
				}
				ToolbarItem {
					Spacer()
				}
				ToolbarItem {
					Button(action: {
					}, label: {
						AppAssets.nextUnreadArticleImage
							.resizable()
							.scaledToFit()
							.frame(width: 22, height: 22, alignment: .center)
					})
				}
				#endif
			}
	}
	
}
