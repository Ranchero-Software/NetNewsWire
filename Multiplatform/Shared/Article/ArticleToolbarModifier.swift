//
//  ArticleToolbarModifier.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 7/5/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct ArticleToolbarModifier: ViewModifier {
	
	@EnvironmentObject private var sceneModel: SceneModel
	
	func body(content: Content) -> some View {
		content
			.toolbar {
				#if os(iOS)
				
				ToolbarItem(placement: .navigation) {
					HStack(spacing: 20) {
						Button(action: {
						}, label: {
							AppAssets.prevArticleImage
								.font(.title3)
						}).help("Previouse Unread")
						Button(action: {
						}, label: {
							AppAssets.nextArticleImage
								.font(.title3)
						}).help("Next Unread")
					}
				}

				ToolbarItem(placement: .bottomBar) {
					Button(action: { sceneModel.toggleReadForCurrentArticle() }, label: {
						if sceneModel.readButtonState == .on {
							AppAssets.readClosedImage
						} else {
							AppAssets.readOpenImage
						}
					})
					.disabled(sceneModel.readButtonState == nil ? true : false)
					.help(sceneModel.readButtonState == .on ? "Mark as Unread" : "Mark as Read")
				}

				ToolbarItem(placement: .bottomBar) {
					Spacer()
				}
				
				ToolbarItem(placement: .bottomBar) {
					Button(action: { sceneModel.toggleStarForCurrentArticle() }, label: {
						if sceneModel.starButtonState == .on {
							AppAssets.starClosedImage
						} else {
							AppAssets.starOpenImage
						}
					})
					.disabled(sceneModel.starButtonState == nil ? true : false)
					.help(sceneModel.starButtonState == .on ? "Mark as Unstarred" : "Mark as Starred")
				}

				ToolbarItem(placement: .bottomBar) {
					Spacer()
				}
				
				ToolbarItem(placement: .bottomBar) {
					Button(action: {
					}, label: {
						AppAssets.nextUnreadArticleImage
							.font(.title3)
					}).help("Next Unread")
				}

				ToolbarItem(placement: .bottomBar) {
					Spacer()
				}
				
				ToolbarItem(placement: .bottomBar) {
					Button(action: {
					}, label: {
						AppAssets.articleExtractorOff
							.font(.title3)
					}).help("Reader View")
				}

				ToolbarItem(placement: .bottomBar) {
					Spacer()
				}
				
				ToolbarItem(placement: .bottomBar) {
					Button(action: {
					}, label: {
						AppAssets.shareImage
							.font(.title3)
					}).help("Share")
				}

				#endif
			}
	}
	
}
