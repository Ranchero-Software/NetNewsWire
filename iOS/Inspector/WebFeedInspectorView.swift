//
//  WebFeedInspectorView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 15/12/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import SafariServices
import UserNotifications

struct WebFeedInspectorView: View {
   
	var webFeed: WebFeed!
	@State private var showHomePage: Bool = false
	
	var body: some View {
		Form {
			
			Section(header: webFeedHeaderView) {}
			
			Section {
				TextField(webFeed.nameForDisplay,
						  text: Binding(
							get: { webFeed.name ?? webFeed.nameForDisplay },
							set: { webFeed.name = $0 }),
						  prompt: nil)

				Toggle(isOn: Binding(get: { webFeed.isNotifyAboutNewArticles ?? false }, set: { webFeed.isNotifyAboutNewArticles = $0 })) {
					Text("toggle.title.notify-about-new-articles", comment: "New Article Notifications")
				}

				if webFeed.isFeedProvider == false {
					Toggle(isOn: Binding(
						get: { webFeed.isArticleExtractorAlwaysOn ?? false },
						set: { webFeed.isArticleExtractorAlwaysOn = $0 })) {
						Text("toggle.title.always-show-reader-view", comment: "Always Show Reader View")
					}
				}
			}
			
			Section(header: Text("label.text.home-page", comment: "Home Page")) {
				HStack {
					Text(webFeed.homePageURL?.decodedURLString ?? "")
					Spacer()
					Image(uiImage: AppAssets.safariImage)
						.renderingMode(.template)
						.foregroundColor(Color(uiColor: AppAssets.primaryAccentColor))
				}
				.onTapGesture {
					if webFeed.homePageURL != nil { showHomePage = true }
				}
			}

			Section(header: Text("label.text.feed-url", comment: "Feed URL")) {
				Text(webFeed.url.description)
			}
		}
		.navigationBarTitleDisplayMode(.inline)
		.navigationTitle(webFeed.nameForDisplay)
		.sheet(isPresented: $showHomePage, onDismiss: nil) {
			SafariView(url: URL(string: webFeed.homePageURL!)!)
		}
		.tint(Color(uiColor: AppAssets.primaryAccentColor))
		.dismissOnExternalContextLaunch()
    }
	
	var webFeedHeaderView: some View {
		HStack {
			Spacer()
			Image(uiImage: webFeed.smallIcon!.image)
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(width: 48, height: 48)
				.clipShape(RoundedRectangle(cornerRadius: 4))
			Spacer()
		}
	}
}

struct WebFeedInspectorView_Previews: PreviewProvider {
    static var previews: some View {
        WebFeedInspectorView()
    }
}
