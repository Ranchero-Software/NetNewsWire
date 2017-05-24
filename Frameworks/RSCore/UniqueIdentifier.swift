//
//  UniqueIdentifier.swift
//  RSCore
//
//  Created by Brent Simmons on 5/24/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public func uniqueIdentifier() -> String {
	
	return UUID().uuidString
}
