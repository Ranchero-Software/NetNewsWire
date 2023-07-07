//
//  WebInspectorView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 15/12/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import SafariServices
import UserNotifications

struct FeedInspectorView: View {
   
	var feed: Feed!
	@State private var showHomePage: Bool = false
	
	var body: some View {
		Form {
			
			Section(header: feedHeaderView) {}
			
			Section {
				TextField(feed.nameForDisplay,
						  text: Binding(
							get: { feed.name ?? feed.nameForDisplay },
							set: { feed.name = $0 }),
						  prompt: nil)

				Toggle(isOn: Binding(get: { feed.isNotifyAboutNewArticles ?? false }, set: { feed.isNotifyAboutNewArticles = $0 })) {
					Text("toggle.title.notify-about-new-articles", comment: "New Article Notifications")
				}
			}
			
			Section(header: Text("label.text.home-page", comment: "Home Page")) {
				HStack {
					Text(feed.homePageURL?.decodedURLString ?? "")
					Spacer()
					Image(uiImage: AppAssets.safariImage)
						.renderingMode(.template)
						.foregroundColor(Color(uiColor: AppAssets.primaryAccentColor))
				}
				.onTapGesture {
					if feed.homePageURL != nil { showHomePage = true }
				}
			}

			Section(header: Text("label.text.feed-url", comment: "Feed URL")) {
				Text(feed.url.description)
			}
		}
		.navigationBarTitleDisplayMode(.inline)
		.navigationTitle(feed.nameForDisplay)
		.sheet(isPresented: $showHomePage, onDismiss: nil) {
			SafariView(url: URL(string: feed.homePageURL!)!)
		}
		.tint(Color(uiColor: AppAssets.primaryAccentColor))
		.dismissOnExternalContextLaunch()
    }
	
	@MainActor var feedHeaderView: some View {
		HStack {
			Spacer()
			Image(uiImage: feed.smallIcon!.image)
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(width: 48, height: 48)
				.clipShape(RoundedRectangle(cornerRadius: 4))
			Spacer()
		}
	}
}

struct FeedInspectorView_Previews: PreviewProvider {
    static var previews: some View {
        FeedInspectorView()
    }
}
