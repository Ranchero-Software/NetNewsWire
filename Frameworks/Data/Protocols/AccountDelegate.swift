//
//  AccountDelegate.swift
//  DataModel
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol AccountDelegate {

	func canAddItem(_ item: AnyObject, toContainer: Container) -> Bool

}

