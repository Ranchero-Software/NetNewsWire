//
//  ExtensionPointManager.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import FeedProvider
import RSCore

struct ExtensionPointManager {
	
	static let shared = ExtensionPointManager()
	
	let marsEdit = SendToMarsEditCommand()
	let microblog = SendToMicroBlogCommand()
	let twitter = TwitterFeedProvider()
	
	let availableExtensionPoints: [ExtensionPoint]
	let activeSendToCommands: [SendToCommand]
	let activeFeedProviders: [FeedProvider]
	
	init() {
		#if os(macOS)
		#if DEBUG
		availableExtensionPoints = [marsEdit, microblog, twitter]
		activeSendToCommands = [marsEdit, microblog]
		activeFeedProviders = [twitter]
		#else
		availableExtensionPoints = [marsEdit, microblog, twitter]
		activeSendToCommands = [marsEdit, microblog]
		activeFeedProviders = [twitter]
		#endif
		#else
		#if DEBUG
		availableExtensionPoints = [twitter]
		activeSendToCommands = []()
		activeFeedProviders = [twitter]
		#else
		availableExtensionPoints = [twitter]
		activeSendToCommands = []()
		activeFeedProviders = [twitter]
		#endif
		#endif
	}
	
}
