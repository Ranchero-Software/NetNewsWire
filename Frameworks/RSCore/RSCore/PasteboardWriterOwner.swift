//
//  PasteboardWriterOwner.swift
//  RSCore
//
//  Created by Brent Simmons on 2/11/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import AppKit

public protocol PasteboardWriterOwner {

	var pasteboardWriter: NSPasteboardWriting { get }
}
