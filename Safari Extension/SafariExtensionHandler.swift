//
//  SafariExtensionHandler.swift
//  Subscribe to Feed
//
//  Created by Daniel Jalkut on 6/11/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import SafariServices

class SafariExtensionHandler: SFSafariExtensionHandler {

	// Safari App Extensions don't support any reasonable means of detecting whether a
	// specific Safari page was loaded with the benefit of the extension's injected
	// JavaScript. For this reason a condition can easily be reached where the toolbar
	// icon is active for a page, but the expected supporting code is not loaded into
	// the page. To detect this and disable our icon, we use a kind of "ping" trick
	// to verify whether our code is installed.

	// I tried to use a NSMapTable from String to the closure directly, but Swift
	// complains that the object has to be a class type.
	typealias ValidationHandler = (Bool, String) -> Void
	class ValidationWrapper {
		let validationHandler: ValidationHandler

		init(validationHandler: @escaping ValidationHandler) {
			self.validationHandler = validationHandler
		}
	}

	// Maps from UUID to a validation wrapper
	static var gPingPongMap = Dictionary<String, ValidationWrapper>()
	static var validationQueue = DispatchQueue(label: "Toolbar Validation")

	// Bottleneck for calling through to a validation handler we have saved, and removing it from the list.
	static func callValidationHandler(forHandlerID handlerID: String, withShouldValidate shouldValidate: Bool) {
		if let validationWrapper = gPingPongMap[handlerID] {
			validationWrapper.validationHandler(shouldValidate, "")
			gPingPongMap.removeValue(forKey: handlerID)
		}
	}

    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String : Any]?) {
		if (messageName == "subscribeToFeed") {
			if let feedURLString = userInfo?["url"] as? String {
				if let feedURL = URL(string: feedURLString) {
					// We could do something more NetNewsWire-specific like invoke an app-specific scheme
					// to subscribe in the app. For starters we just let NSWorkspace open the URL in the
					// default "feed:" URL scheme handler.
					NSWorkspace.shared.open(feedURL)
				}
			}
		}
		else if (messageName == "pong") {
			if let validationIDString = userInfo?["validationID"] as? String {
				// Should we validate the button?
				let shouldValidate = userInfo?["shouldValidate"] as? Bool ?? false
				SafariExtensionHandler.callValidationHandler(forHandlerID: validationIDString, withShouldValidate:shouldValidate)
			}
		}
    }
    
    override func toolbarItemClicked(in window: SFSafariWindow) {
		window.getActiveTab { (activeTab) in
			activeTab?.getActivePage(completionHandler: { (activePage) in
				activePage?.dispatchMessageToScript(withName: "toolbarButtonClicked", userInfo: nil)
			})
		}
    }

    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping ((Bool, String) -> Void)) {

		let uniqueValidationID = NSUUID().uuidString

		SafariExtensionHandler.validationQueue.sync {

			// Save it right away to eliminate any doubt of whether the handler gets deallocated while
			// we are waiting for a callback from the getActiveTab or getActivatePage methods below.
			let validationWrapper = ValidationWrapper(validationHandler: validationHandler)
			SafariExtensionHandler.gPingPongMap[uniqueValidationID] = validationWrapper

			// To avoid problems with validation handlers dispatched after we've, for example,
			// switched to a new tab, we aggressively clear out the map of any pending validations,
			// and focus only on the newest validation request we've been asked for.
			for thisValidationID in SafariExtensionHandler.gPingPongMap.keys {
				if thisValidationID != uniqueValidationID {
					// Default to valid ... we'll know soon enough whether the latest state
					// is actually still valid or not...
					SafariExtensionHandler.callValidationHandler(forHandlerID: thisValidationID, withShouldValidate: true);

				}
			}

			// See comments above where gPingPongMap is declared. Upon being asked to validate the
			// toolbar icon for a specific page, we save the validationHandler and postpone calling
			// it until we have either received a response from our installed JavaScript, or until
			// a timeout period has elapsed
			window.getActiveTab { (activeTab) in
				guard let activeTab = activeTab else {
					SafariExtensionHandler.callValidationHandler(forHandlerID: uniqueValidationID, withShouldValidate:false);
					return
				}

				activeTab.getActivePage { (activePage) in
					guard let activePage = activePage else {
						SafariExtensionHandler.callValidationHandler(forHandlerID: uniqueValidationID, withShouldValidate:false);
						return						
					}

					activePage.getPropertiesWithCompletionHandler { (pageProperties) in
						if let isActive = pageProperties?.isActive {
							if isActive {
								// Capture the uniqueValidationID to ensure it doesn't change out from under us on a future call
								activePage.dispatchMessageToScript(withName: "ping", userInfo: ["validationID": uniqueValidationID])

								let pongTimeoutInNanoseconds = Int(Double(NSEC_PER_SEC) * 0.5)
								let timeoutDeadline = DispatchTime.now() + DispatchTimeInterval.nanoseconds(pongTimeoutInNanoseconds)
								DispatchQueue.main.asyncAfter(deadline: timeoutDeadline, execute: { [timedOutValidationID = uniqueValidationID] in
									SafariExtensionHandler.callValidationHandler(forHandlerID: timedOutValidationID, withShouldValidate:false)
								})
							}
						}
					}
				}
			}
		}
    }
}
