//
//  URLPasteboardWriter+NetNewsWire.swift
//  NetNewsWire
//
//  Created by Nate Weaver on 2022-10-10.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import RSCore

extension URLPasteboardWriter {

	static func write(urlStrings: [String?], to pasteboard: NSPasteboard = .general, alertingInWindow window: NSWindow?) {
		URLPasteboardWriter.write(urlStrings: urlStrings.compactMap { $0 }, to: pasteboard)

		if urlStrings.contains(nil), !AppDefaults.shared.hasSeenNotAllArticlesHaveURLsAlert, let window {
			let alert = NSAlert()
			alert.messageText = NSLocalizedString("Some articles don’t have links, so they weren't copied.", comment: "")
			alert.informativeText = NSLocalizedString("You won't see this message again.", comment: "")

			alert.beginSheetModal(for: window)

			AppDefaults.shared.hasSeenNotAllArticlesHaveURLsAlert = true
		}
	}

}
