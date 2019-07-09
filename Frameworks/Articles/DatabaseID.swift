//
//  DatabaseID.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/15/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore

// MD5 works because:
// * It’s fast
// * Collisions aren’t going to happen with feed data

private var databaseIDCache = [String: String]()
private var databaseIDCacheLock = os_unfair_lock_s()

public func databaseIDWithString(_ s: String) -> String {
	os_unfair_lock_lock(&databaseIDCacheLock)
	defer {
		os_unfair_lock_unlock(&databaseIDCacheLock)
	}
	
	if let identifier = databaseIDCache[s] {
		return identifier
	}
	
	let identifier = (s as NSString).rs_md5Hash()
	databaseIDCache[s] = identifier
	return identifier
}
