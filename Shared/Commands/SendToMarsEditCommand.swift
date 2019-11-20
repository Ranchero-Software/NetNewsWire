//
//  SendToMarsEditCommand.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 1/8/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import RSCore
import Articles

final class SendToMarsEditCommand: SendToCommand {

	let title = "MarsEdit"

	var image: NSImage? {
		return appToUse()?.icon ?? nil
	}

	private let marsEditApps = [UserApp(bundleID: "com.red-sweater.marsedit4"), UserApp(bundleID: "com.red-sweater.marsedit")]

	func canSendObject(_ object: Any?, selectedText: String?) -> Bool {

		if let _ = appToUse() {
			return true
		}
		return false
	}

	func sendObject(_ object: Any?, selectedText: String?) {

		guard canSendObject(object, selectedText: selectedText) else {
			return
		}
		guard let article = (object as? ArticlePasteboardWriter)?.article else {
			return
		}
		guard let app = appToUse(), app.launchIfNeeded(), app.bringToFront() else {
			return
		}

		send(article, to: app)
	}
}

private extension SendToMarsEditCommand {

	func send(_ article: Article, to app: UserApp) {

		// App has already been launched.

		guard let targetDescriptor = app.targetDescriptor() else {
			return
		}

		let body = article.contentHTML ?? article.contentText ?? article.summary
		let authorName = article.authors?.first?.name

		let sender = SendToBlogEditorApp(targetDesciptor: targetDescriptor, title: article.title, body: body, summary: article.summary, link: article.externalURL, permalink: article.url, subject: nil, creator: authorName, commentsURL: nil, guid: article.uniqueID, sourceName: article.webFeed?.nameForDisplay, sourceHomeURL: article.webFeed?.homePageURL, sourceFeedURL: article.webFeed?.url)
		let _ = sender.send()
	}
	
	func appToUse() -> UserApp? {

		marsEditApps.forEach{ $0.updateStatus() }

		for app in marsEditApps {
			if app.isRunning {
				return app
			}
		}

		for app in marsEditApps {
			if app.existsOnDisk {
				return app
			}
		}

		return nil
	}
}
