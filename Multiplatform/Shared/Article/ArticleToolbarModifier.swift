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
	@EnvironmentObject private var sceneNavigationModel: SceneNavigationModel
	@State private var showActivityView = false
	
	func body(content: Content) -> some View {
		content
			.toolbar {
				#if os(iOS)
				
				ToolbarItem(placement: .primaryAction) {
					HStack(spacing: 20) {
						Button {
						} label: {
							AppAssets.prevArticleImage
								.font(.title3)
						}
						.help("Previouse Unread")
						Button {
						} label: {
							AppAssets.nextArticleImage.font(.title3)
						}
						.help("Next Unread")
					}
				}

				ToolbarItem(placement: .bottomBar) {
					Button {
						sceneModel.toggleReadStatusForSelectedArticles()
					} label: {
						if sceneModel.readButtonState == true {
							AppAssets.readClosedImage
						} else {
							AppAssets.readOpenImage
						}
					}
					.disabled(sceneModel.readButtonState == nil)
					.help(sceneModel.readButtonState ?? false ? "Mark as Unread" : "Mark as Read")
				}

				ToolbarItem(placement: .bottomBar) {
					Spacer()
				}
				
				ToolbarItem(placement: .bottomBar) {
					Button {
						sceneModel.toggleStarredStatusForSelectedArticles()
					} label: {
						if sceneModel.starButtonState ?? false {
							AppAssets.starClosedImage
						} else {
							AppAssets.starOpenImage
						}
					}
					.disabled(sceneModel.starButtonState == nil)
					.help(sceneModel.starButtonState ?? false ? "Mark as Unstarred" : "Mark as Starred")
				}

				ToolbarItem(placement: .bottomBar) {
					Spacer()
				}
				
				ToolbarItem(placement: .bottomBar) {
					Button {
						sceneModel.goToNextUnread()
					} label: {
						AppAssets.nextUnreadArticleImage.font(.title3)
					}
					.disabled(sceneModel.nextUnreadButtonState == nil)
					.help("Next Unread")
				}

				ToolbarItem(placement: .bottomBar) {
					Spacer()
				}
				
				ToolbarItem(placement: .bottomBar) {
					Button {
					} label: {
						AppAssets.articleExtractorOff
							.font(.title3)
					}
					.disabled(sceneModel.extractorButtonState == nil)
					.help("Reader View")
				}

				ToolbarItem(placement: .bottomBar) {
					Spacer()
				}
				
				ToolbarItem(placement: .bottomBar) {
					Button {
						showActivityView.toggle()
					} label: {
						AppAssets.shareImage.font(.title3)
					}
					.disabled(sceneModel.shareButtonState == nil)
					.help("Share")
					.sheet(isPresented: $showActivityView) {
						if let article = sceneModel.selectedArticles.first, let url = article.preferredURL {
							ActivityViewController(title: article.title, url: url)
						}
					}
				}
				#else
				ToolbarItem {
					Button {
						sceneModel.goToNextUnread()
					} label: {
						AppAssets.nextUnreadArticleImage
					}
					.disabled(sceneModel.nextUnreadButtonState == nil)
					.help("Go to Next Unread")
				}
				ToolbarItem {
					Button {
						sceneModel.toggleReadStatusForSelectedArticles()
					} label: {
						if sceneModel.readButtonState ?? false {
							AppAssets.readClosedImage
						} else {
							AppAssets.readOpenImage
						}
					}
					.disabled(sceneModel.readButtonState == nil)
					.help(sceneModel.readButtonState ?? false ? "Mark as Unread" : "Mark as Read")
				}
				ToolbarItem {
					Button {
						sceneModel.toggleStarredStatusForSelectedArticles()
					} label: {
						if sceneModel.starButtonState ?? false {
							AppAssets.starClosedImage
						} else {
							AppAssets.starOpenImage
						}
					}
					.disabled(sceneModel.starButtonState == nil)
					.help(sceneModel.starButtonState ?? false ? "Mark as Unstarred" : "Mark as Starred")
				}
				ToolbarItem {
					Button {
					} label: {
						AppAssets.articleExtractorOff
					}
					.disabled(sceneModel.extractorButtonState == nil)
					.help("Show Reader View")
				}
				ToolbarItem {
					Button {
						sceneModel.openSelectedArticleInBrowser()
					} label: {
						AppAssets.openInBrowserImage
					}
					.disabled(sceneModel.openInBrowserButtonState == nil)
					.help("Open in Browser")
				}
				ToolbarItem {
					ZStack {
						if sceneNavigationModel.showShareSheet {
							SharingServiceView(articles: sceneModel.selectedArticles, showing: $sceneNavigationModel.showShareSheet)
								.frame(width: 20, height: 20)
						}
						Button {
							sceneNavigationModel.showShareSheet = true
						} label: {
							AppAssets.shareImage
						}
					}
					.disabled(sceneModel.shareButtonState == nil)
					.help("Share")
				}

				#endif
			}
	}
	
}
