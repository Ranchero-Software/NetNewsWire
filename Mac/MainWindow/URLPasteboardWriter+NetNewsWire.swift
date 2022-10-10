//
//  URLPasteboardWriter+NetNewsWire.swift
//  NetNewsWire
//
//  Created by Nate Weaver on 2022-10-10.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import RSCore

extension URLPasteboardWriter {

	/// Copy URL strings, alerting the user the first time the array of URL strings contains `nil`.
	/// - Parameters:
	///   - urlStrings: The URL strings to copy.
	///   - pasteboard: The pastebaord to copy to.
	///   - window: The window to use as a sheet parent for the alert. If `nil`, will run the alert modally.
	static func write(urlStrings: [String?], to pasteboard: NSPasteboard = .general, alertingInWindow window: NSWindow?) {
		URLPasteboardWriter.write(urlStrings: urlStrings.compactMap { $0 }, to: pasteboard)

		if urlStrings.contains(nil), !AppDefaults.shared.hasSeenNotAllArticlesHaveURLsAlert {
			let alert = NSAlert()
			alert.messageText = NSLocalizedString("Some articles don’t have links, so they weren't copied.", comment: "\"Some articles have no links\" copy alert message text")
			alert.informativeText = NSLocalizedString("You won't see this message again.", comment: "You won't see this message again")

			if let window {
				alert.beginSheetModal(for: window)
			} else {
				alert.runModal() // this should never happen
			}

			AppDefaults.shared.hasSeenNotAllArticlesHaveURLsAlert = true
		}
	}

}
