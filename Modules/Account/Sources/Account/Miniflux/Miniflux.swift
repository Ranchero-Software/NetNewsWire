//
//  Miniflux.swift
//  Account
//
//  Created by Dave Marquard on 7/7/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os

struct Miniflux {
	// Convention with this logger is to put "Miniflux: " at the beginning of each message.
	static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "NetNewsWire", category: "Miniflux")
}
