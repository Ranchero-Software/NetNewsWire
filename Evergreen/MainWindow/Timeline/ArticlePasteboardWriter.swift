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

		// TODO: add more types

		var types = [NSPasteboard.PasteboardType]()

		if let _ = article.title {
			types += [.string]
		}
		if let link = article.preferredLink, let _ = URL(string: link) {
			types += [.URL]
		}

		return types // TODO: add types
	}

	func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {

		// TODO: write data for all types declared in writableTypes.

		let plist: Any?

		switch type {
		case .string:
			plist = article.title ?? ""
		case .URL:
			plist = article.preferredLink ?? ""
		default:
			plist = nil
		}

		return plist
	}
}
