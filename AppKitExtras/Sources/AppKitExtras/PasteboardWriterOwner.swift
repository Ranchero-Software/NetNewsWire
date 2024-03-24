//
//  PasteboardWriterOwner.swift
//  RSCore
//
//  Created by Brent Simmons on 2/11/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//
#if os(macOS)
import AppKit

public protocol PasteboardWriterOwner {

	@MainActor var pasteboardWriter: NSPasteboardWriting { get }
}
#endif
