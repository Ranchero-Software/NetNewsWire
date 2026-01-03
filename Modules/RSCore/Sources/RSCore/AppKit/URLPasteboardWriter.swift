//
//  URLPasteboardWriter.swift
//  RSCore
//
//  Created by Brent Simmons on 1/28/18.
//  Copyright © 2018 Brent Simmons. All rights reserved.
//

#if os(macOS)

import AppKit

/// Takes a string, not a URL, but writes it as a URL (when possible) and as a String.
@objc public final class URLPasteboardWriter: NSObject, NSPasteboardWriting {
	let urlString: String

	public init(urlString: String) {
		self.urlString = urlString
	}

	public static func write(urlString: String, to pasteboard: NSPasteboard) {
		write(urlStrings: [urlString], to: pasteboard)
	}

	public static func write(urlStrings: [String], to pasteboard: NSPasteboard) {
		assert(!urlStrings.isEmpty)
		guard !urlStrings.isEmpty else {
			return
		}

		pasteboard.clearContents()
		let writers = urlStrings.map { URLPasteboardWriter(urlString: $0) }
		pasteboard.writeObjects(writers)
	}

	// MARK: - NSPasteboardWriting

	public func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
		if URL(string: urlString) != nil {
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
