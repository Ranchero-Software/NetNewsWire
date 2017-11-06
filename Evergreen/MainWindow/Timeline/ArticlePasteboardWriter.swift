//
//  ArticlePasteboardWriter.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/6/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Cocoa
import Data

@objc final class ArticlePasteboardWriter: NSObject, NSPasteboardWriting {

	private let article: Article

	init(article: Article) {

		self.article = article
	}

	// MARK: - NSPasteboardWriting

	func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {

		return [NSPasteboard.PasteboardType]() // TODO: add types
	}

	func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {

		return nil // TODO: write data
	}
}
