//
//  InspectorItem.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/15/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation

protocol InspectorItem: class {

	var localizedTitle: String { get }
	var view: NSView { get }
	var inspectedObjects: [Any]? { get set }
	var expanded: Bool { get set }

	func canInspect(_ objects: [Any]) -> Bool
}
