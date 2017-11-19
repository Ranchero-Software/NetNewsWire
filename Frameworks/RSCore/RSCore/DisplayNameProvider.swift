//
//  DisplayNameProviderProtocol.swift
//  DataModel
//
//  Created by Brent Simmons on 7/28/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol DisplayNameProvider {
	
	var nameForDisplay: String { get }
}

