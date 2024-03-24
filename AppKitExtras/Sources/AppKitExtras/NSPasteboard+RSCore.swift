//
//  NSPasteboard+RSCore.swift
//  RSCore
//
//  Created by Brent Simmons on 2/11/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//
#if os(macOS)
import AppKit

public extension NSPasteboard {

	@MainActor func copyObjects(_ objects: [Any]) {

		guard let writers = writersFor(objects) else {
			return
		}

		clearContents()
		writeObjects(writers)
	}

	func canCopyAtLeastOneObject(_ objects: [Any]) -> Bool {

		for object in objects {
			if object is PasteboardWriterOwner {
				return true
			}
		}
		return false
	}

}

public extension NSPasteboard {

	static func urlString(from pasteboard: NSPasteboard) -> String? {
		return pasteboard.urlString
	}

	private var urlString: String? {
		guard let type = self.availableType(from: [.string]) else {
			return nil
		}

		guard let str = self.string(forType: type), !str.isEmpty else {
			return nil
		}

		return str.mayBeURL ? str : nil
	}

}

private extension NSPasteboard {

	@MainActor func writersFor(_ objects: [Any]) -> [NSPasteboardWriting]? {

		let writers = objects.compactMap { ($0 as? PasteboardWriterOwner)?.pasteboardWriter }
		return writers.isEmpty ? nil : writers
	}
}
#endif
