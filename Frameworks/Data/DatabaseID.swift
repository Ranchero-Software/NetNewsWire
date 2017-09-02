//
//  DatabaseID.swift
//  Data
//
//  Created by Brent Simmons on 7/15/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation

// MD5 works because:
// * It’s fast
// * Collisions aren’t going to happen with feed data

private var databaseIDCache = [String: String]()

public func databaseIDWithString(_ s: String) -> String {

	if let identifier = databaseIDCache[s] {
		return identifier
	}
	
	let identifier = (s as NSString).rs_md5Hash()
	databaseIDCache[s] = identifier
	return identifier
}
