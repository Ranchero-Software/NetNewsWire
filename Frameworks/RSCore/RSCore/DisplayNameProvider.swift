//
//  DisplayNameProviderProtocol.swift
//  DataModel
//
//  Created by Brent Simmons on 7/28/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

extension Notification.Name {

	public static let DisplayNameDidChange = Notification.Name("DisplayNameDidChange")
}


public protocol DisplayNameProvider {
	
	var nameForDisplay: String { get }
}

public extension DisplayNameProvider {

	func postDisplayNameDidChangeNotification() {

		NotificationCenter.default.post(name: .DisplayNameDidChange, object: self, userInfo: nil)
	}
}
