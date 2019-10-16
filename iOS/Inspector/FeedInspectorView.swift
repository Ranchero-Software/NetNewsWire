//
//  FeedInspector.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/27/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import SwiftUI
import Combine
import Account

struct FeedInspectorView : View {
	
	@ObservedObject var viewModel: ViewModel
	@Environment(\.colorScheme) private var colorScheme: ColorScheme
	@Environment(\.viewController) private var viewController: UIViewController?

    var body: some View {
		NavigationView {
			Form {
				Section(header:
					HStack {
						Spacer()
						if self.viewModel.image.size.width < 32 || self.viewModel.image.size.height < 32 {
							if colorScheme == .dark && self.viewModel.image.isDark() {
								Image(uiImage: self.viewModel.image)
								.resizable()
								.background(Color(AppAssets.avatarBackgroundColor))
								.frame(width: 24.0, height: 24.0)
								.cornerRadius(2.0)
							} else {
								Image(uiImage: self.viewModel.image)
									.resizable()
									.frame(width: 24.0, height: 24.0)
									.cornerRadius(2.0)
							}
						} else {
							if colorScheme == .dark && self.viewModel.image.isDark() {
								Image(uiImage: self.viewModel.image)
									.resizable()
									.background(Color(AppAssets.avatarBackgroundColor))
									.frame(width: 48.0, height: 48.0)
									.cornerRadius(5.0)
							} else {
								Image(uiImage: self.viewModel.image)
									.resizable()
									.frame(width: 48.0, height: 48.0)
									.cornerRadius(5.0)
							}
						}
						Spacer()
					}) {
					TextField("Feed Name", text: $viewModel.name)
					Toggle(isOn: $viewModel.isNotifyAboutNewArticles) {
						Text("Notify About New Articles")
					}
					Toggle(isOn: $viewModel.isArticleExtractorAlwaysOn) {
						Text("Always Show Reader View")
					}
				}
				Section(header: Text("HOME PAGE")) {
					Text(verbatim: self.viewModel.homePageURL)
				}
				Section(header: Text("FEED URL")) {
					Text(verbatim: self.viewModel.feedLinkURL)
				}
			}
			.navigationBarTitle(Text(verbatim: self.viewModel.nameForDisplay), displayMode: .inline)
			.navigationBarItems(leading: Button(action: { self.viewController?.dismiss(animated: true) }) { Text("Done") } )
		}
    }
	
	// MARK: ViewModel
	
	class ViewModel: ObservableObject {
		
		let objectWillChange = ObservableObjectPublisher()
		let feed: Feed
		
		init(feed: Feed) {
			self.feed = feed
			NotificationCenter.default.addObserver(self, selector: #selector(feedIconDidBecomeAvailable(_:)), name: .FeedIconDidBecomeAvailable, object: nil)
		}
		
		var image: UIImage {
			if let feedIcon = appDelegate.feedIconDownloader.icon(for: feed) {
				return feedIcon
			}
			if let favicon = appDelegate.faviconDownloader.favicon(for: feed) {
				return favicon
			}
			return FaviconGenerator.favicon(feed)
		}
		
		var nameForDisplay: String {
			return feed.nameForDisplay
		}
		
		var name: String {
			get {
				return feed.editedName ?? ""
			}
			set {
				objectWillChange.send()
				if newValue.isEmpty {
					feed.editedName = nil
				} else {
					feed.editedName = newValue
				}
			}
		}
		
		var isNotifyAboutNewArticles: Bool {
			get {
				return feed.isNotifyAboutNewArticles ?? false
			}
			set {
				objectWillChange.send()
				feed.isNotifyAboutNewArticles = newValue
			}
		}

		var isArticleExtractorAlwaysOn: Bool {
			get {
				return feed.isArticleExtractorAlwaysOn ?? false
			}
			set {
				objectWillChange.send()
				feed.isArticleExtractorAlwaysOn = newValue
			}
		}
		
		var homePageURL: String {
			return feed.homePageURL ?? ""
		}
		
		var feedLinkURL: String {
			return feed.url
		}

		@objc func feedIconDidBecomeAvailable(_ notification: Notification) {
			objectWillChange.send()
		}

	}

}
