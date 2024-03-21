//
//  URLPasteboardWriter.swift
//  RSCore
//
//  Created by Brent Simmons on 1/28/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//
#if os(macOS)
import AppKit

// Takes a string, not a URL, but writes it as a URL (when possible) and as a String.

@objc public final class URLPasteboardWriter: NSObject, NSPasteboardWriting {

	let urlString: String

	public init(urlString: String) {

		self.urlString = urlString
	}

	public class func write(urlString: String, to pasteboard: NSPasteboard) {

		pasteboard.clearContents()
		let writer = URLPasteboardWriter(urlString: urlString)
		pasteboard.writeObjects([writer])
	}

	// MARK: - NSPasteboardWriting

	public func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {

		if let _ = URL(string: urlString) {
			return [.URL, .string]
		}
		return [.string]
	}

	public func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {

		guard type == .string || type == .URL else {
			return nil
		}
		return urlString
	}
}
#endif
