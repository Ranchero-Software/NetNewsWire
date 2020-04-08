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
	
	let availableExtensionPointTypes: [ExtensionPointType]
//	let activeSendToCommands: [SendToCommand]
//	let activeFeedProviders: [FeedProvider]
	
	init() {
		#if os(macOS)
		#if DEBUG
		availableExtensionPointTypes = [.marsEdit, .microblog, .twitter]
		#else
		availableExtensionPointTypes = [.marsEdit, .microblog, .twitter]
		#endif
		#else
		#if DEBUG
		availableExtensionPoints = [.twitter]
		#else
		availableExtensionPoints = [.twitter]
		#endif
		#endif
	}
	
}
