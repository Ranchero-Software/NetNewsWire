//
//  RSColor.swift
//
//
//  Created by Brent Simmons on 7/9/24.
//

#if os(macOS)
import AppKit
public typealias RSColor = NSColor
#endif

#if os(iOS)
import UIKit
public typealias RSColor = UIColor
#endif
