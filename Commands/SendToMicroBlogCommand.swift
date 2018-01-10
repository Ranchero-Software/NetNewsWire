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

	private let bundleID = "blog.micro.mac"
	private var appExists = false

	init() {

		self.appExists = appExistsOnDisk(bundleID)
		NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive(_:)), name: NSApplication.didBecomeActiveNotification, object: nil)
	}

	func canSendObject(_ object: Any?, selectedText: String?) -> Bool {

		guard appExists else {
			return false
		}
		guard let article = object as? Article else {
			return false
		}
		guard let _ = article.preferredLink else {
			return false
		}

		return true
	}
	
	func sendObject(_ object: Any?, selectedText: String?) {

		guard canSendObject(object, selectedText: selectedText) else {
			return
		}
		guard let article = object as? Article else {
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

		guard let encodedString = s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
			return
		}
		guard let url = URL(string: "microblog://post?text=" + encodedString) else {
			return
		}

		let _ = try? NSWorkspace.shared.open(url, options: [], configuration: [:])
	}

	@objc func appDidBecomeActive(_ note: Notification) {

		self.appExists = appExistsOnDisk(bundleID)
	}
}


