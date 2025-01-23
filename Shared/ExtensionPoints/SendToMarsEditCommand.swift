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
	let image: RSImage? = AppAssets.marsEditIcon

	private let marsEditApps = [UserApp(bundleID: "com.red-sweater.marsedit5"), UserApp(bundleID: "com.red-sweater.marsedit4"), UserApp(bundleID: "com.red-sweater.marsedit")]

	func canSendObject(_ object: Any?, selectedText: String?) -> Bool {
		appToUse() != nil
	}

	func sendObject(_ object: Any?, selectedText: String?) {

		guard canSendObject(object, selectedText: selectedText) else {
			return
		}
		guard let article = (object as? ArticlePasteboardWriter)?.article else {
			return
		}
		guard let app = appToUse() else {
			return
		}

		Task {
			guard await app.launchIfNeeded(), app.bringToFront() else {
				return
			}

			send(article, to: app)
		}
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

		let sender = SendToBlogEditorApp(targetDescriptor: targetDescriptor, title: article.title, body: body, summary: article.summary, link: article.externalLink, permalink: article.link, subject: nil, creator: authorName, commentsURL: nil, guid: article.uniqueID, sourceName: article.feed?.nameForDisplay, sourceHomeURL: article.feed?.homePageURL, sourceFeedURL: article.feed?.url)
		sender.send()
	}

	func appToUse() -> UserApp? {

		for app in marsEditApps {
			app.updateStatus()
		}

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
