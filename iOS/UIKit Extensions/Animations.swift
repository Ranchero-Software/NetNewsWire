//
//  Animations.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 1/27/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation

/// Used to select which animations should be performed
public struct Animations: OptionSet, Sendable {
	
	/// Select and deslections will be animated.
	public static let select = Animations(rawValue: 1)
	
	/// Scrolling will be animated
	public static let scroll = Animations(rawValue: 2)
	
	/// Pushing and popping navigation view controllers will be animated
	public static let navigation = Animations(rawValue: 4)
	
	public let rawValue: Int
	public init(rawValue: Int) {
		self.rawValue = rawValue
	}
}
