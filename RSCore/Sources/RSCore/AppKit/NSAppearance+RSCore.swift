//
//  NSAppearance+RSCore.swift
//  RSCore
//
//  Created by Daniel Jalkut on 8/28/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

#if os(macOS)
import AppKit

extension NSAppearance {

	@objc(rsIsDarkMode)
	public var isDarkMode: Bool {
		return self.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
	}
}
#endif
