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
	
	public var isDarkMode: Bool {
		bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
	}
}
#endif
