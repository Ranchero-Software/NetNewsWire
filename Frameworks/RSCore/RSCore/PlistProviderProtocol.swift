//
//  PlistProviderProtocol.swift
//  RSCore
//
//  Created by Brent Simmons on 7/31/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// For objects that can be serialized as an array or dictionary.
// Mainly used for objects that can be stored on disk.
// Unlike NSCoder it provides human-readable archives.
// Does not do any checking on the contents, but they must be plist objects.

public protocol PlistProvider: class {

	func plist() -> AnyObject?
}
