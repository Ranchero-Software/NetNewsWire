//
//  NSWindowController+RSCore.swift
//  RSCore
//
//  Created by Brent Simmons on 2/17/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import AppKit

public extension NSWindowController {

	public var isDisplayingSheet: Bool {

		return window?.isDisplayingSheet ?? false
	}

	public var isOpen: Bool {

		return isWindowLoaded && window!.isVisible
	}
}
