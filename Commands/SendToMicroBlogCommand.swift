//
//  SendToMicroBlogCommand.swift
//  Evergreen
//
//  Created by Brent Simmons on 1/8/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import Cocoa
import Data

// Not undoable.

final class SendToMicroBlogCommand: SendToCommand {

	let title = NSLocalizedString("Send to Micro.blog", comment: "Send to command")

	var image: NSImage? {
		return microBlogApp.icon
	}

	private let microBlogApp = ApplicationSpecifier(bundleID: "blog.micro.mac")

	func canSendObject(_ object: Any?, selectedText: String?) -> Bool {

		microBlogApp.update()
		guard microBlogApp.existsOnDisk, let article = (object as? ArticlePasteboardWriter)?.article, let _ = article.preferredLink else {
			return false
		}

		return true
	}
	
	func sendObject(_ object: Any?, selectedText: String?) {

		guard canSendObject(object, selectedText: selectedText) else {
			return
		}
		guard let article = (object as? ArticlePasteboardWriter)?.article else {
			return
		}
		guard microBlogApp.existsOnDisk, microBlogApp.launch() else {
			return
		}

		// TODO: get text from contentHTML or contentText if no title and no selectedText.
		var s = ""
		if let selectedText = selectedText {
			s += selectedText
			if let link = article.preferredLink {
				s += "\n\n\(link)"
			}
		}
		else if let title = article.title {
			s += title
			if let link = article.preferredLink {
				s = "[" + s + "](" + link + ")"
			}
		}
		else if let link = article.preferredLink {
			s = link
		}

		let urlQueryDictionary = ["text": s]
		guard let urlQueryString = urlQueryDictionary.urlQueryString() else {
			return
		}
		guard let url = URL(string: "microblog://post?" + urlQueryString) else {
			return
		}

		let _ = try? NSWorkspace.shared.open(url, options: [], configuration: [:])
	}
}


