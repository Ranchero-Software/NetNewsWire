//
//  NSWindowController+RSCore.swift
//  RSCore
//
//  Created by Brent Simmons on 2/17/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//
#if os(macOS)
import AppKit

public extension NSWindowController {

	var isDisplayingSheet: Bool {

		return window?.isDisplayingSheet ?? false
	}

	var isOpen: Bool {

		return isWindowLoaded && window!.isVisible
	}
}
#endif
