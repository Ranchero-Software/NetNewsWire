//
//  SafariExtensionHandler.swift
//  Subscribe to Feed
//
//  Created by Daniel Jalkut on 6/11/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

@preconcurrency import SafariServices

// The extension needs nothing from a page but its URL, which Safari reports directly —
// NetNewsWire's FeedFinder does all feed discovery. Asking Safari rather than an injected
// script means the button also works on pages that were already open when the user granted
// access to the site, which a script can never reach.
// <https://github.com/Ranchero-Software/NetNewsWire/issues/4208>

final class SafariExtensionHandler: SFSafariExtensionHandler {

	override func toolbarItemClicked(in window: SFSafariWindow) {
		SafariExtensionHandler.activePageURL(in: window) { pageURL in
			guard let pageURL else {
				return
			}
			SafariExtensionHandler.openFeedURL("feed:" + pageURL.absoluteString)
		}
	}

	override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping ((Bool, String) -> Void)) {
		// Safari calls back on a Sendable closure, and the validation handler isn't Sendable.
		nonisolated(unsafe) let validationHandler = validationHandler

		SafariExtensionHandler.activePageURL(in: window) { pageURL in
			validationHandler(SafariExtensionHandler.isSubscribablePageURL(pageURL), "")
		}
	}
}

private extension SafariExtensionHandler {

	// Calls completion with the active page's URL, or with nil when there isn't one.
	static func activePageURL(in window: SFSafariWindow, completion: @escaping @Sendable (URL?) -> Void) {
		window.getActiveTab { activeTab in
			guard let activeTab else {
				completion(nil)
				return
			}
			activeTab.getActivePage { activePage in
				guard let activePage else {
					completion(nil)
					return
				}
				activePage.getPropertiesWithCompletionHandler { pageProperties in
					guard let pageProperties, pageProperties.isActive else {
						completion(nil)
						return
					}
					completion(pageProperties.url)
				}
			}
		}
	}

	// True when the page is one we can look for a feed on.
	static func isSubscribablePageURL(_ url: URL?) -> Bool {
		guard let scheme = url?.scheme?.lowercased() else {
			return false
		}
		return scheme == "http" || scheme == "https"
	}

	// Rewrites the scheme so NetNewsWire handles the URL, unless the user would rather it went
	// to the default news reader, and opens it.
	static func openFeedURL(_ urlString: String) {
		var feedURLString = urlString
		var openInDefaultBrowser = false

		// Ask for the user's choice for whether to open the feed URL using whatever the system
		// configured default is, or to always hard-code it to have NetNewsWire handle it itself.
		if let appGroupID = Bundle.main.object(forInfoDictionaryKey: "AppGroup") as? String {
			if let groupDefaults = UserDefaults(suiteName: appGroupID) {
				openInDefaultBrowser = groupDefaults.bool(forKey: "subscribeToFeedsInDefaultBrowser")
			}
		}

		if openInDefaultBrowser == false {
			if feedURLString.hasPrefix("feeds:") {
				feedURLString = "x-netnewswire-feed:" + feedURLString.dropFirst("feeds:".count)
			} else if feedURLString.hasPrefix("feed:") {
				feedURLString = "x-netnewswire-feed:" + feedURLString.dropFirst("feed:".count)
			}
		}

		if let feedURL = URL(string: feedURLString) {
			NSWorkspace.shared.open(feedURL)
		}
	}
}
