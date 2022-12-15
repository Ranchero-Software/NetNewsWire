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
					Text("NOTIFY_ABOUT_NEW_ARTICLES", tableName: "Inspector")
				}

				if webFeed.isFeedProvider == false {
					Toggle(isOn: Binding(
						get: { webFeed.isArticleExtractorAlwaysOn ?? false },
						set: { webFeed.isArticleExtractorAlwaysOn = $0 })) {
						Text("ALWAYS_SHOW_READER_VIEW", tableName: "Inspector")
					}
				}
			}
			
			Section(header: Text("HOME_PAGE", tableName: "Inspector")) {
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

			Section(header: Text("FEED_URL", tableName: "Inspector")) {
				Text(webFeed.url.description)
			}
		}
		.navigationBarTitleDisplayMode(.inline)
		.navigationTitle(webFeed.nameForDisplay)
		.sheet(isPresented: $showHomePage, onDismiss: nil) {
			SafariView(url: URL(string: webFeed.homePageURL!)!)
		}
    }
	
	var webFeedHeaderView: some View {
		HStack {
			Spacer()
			Image(uiImage: webFeed.smallIcon!.image)
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(width: 30, height: 30)
			Spacer()
		}
	}
}

struct WebFeedInspectorView_Previews: PreviewProvider {
    static var previews: some View {
        WebFeedInspectorView()
    }
}
