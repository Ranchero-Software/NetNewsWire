//
//  SendToBlogEditorApp.swift
//  RSCore
//
//  Created by Nate Weaver on 2020-01-04.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

#if os(macOS)
import Foundation
import AppKitExtras

/// This is for sending articles to MarsEdit and other apps that implement the
/// [send-to-blog-editor Apple Events API](http://ranchero.com/netnewswire/developers/externalinterface)\.

public struct SendToBlogEditorApp {

	///The target descriptor of the application.
	///
	/// The easiest way to get this is probably `UserApp.targetDescriptor` or `NSAppleEventDescriptor(runningApplication:)`.
	///
	/// This does not take care of launching the application in the first place.
	/// See UserApp.swift.
	private let targetDescriptor: NSAppleEventDescriptor
	private let title: String?
	private let body: String?
	private let summary: String?
	private let link: String?
	private let permalink: String?
	private let subject: String?
	private let creator: String?
	private let commentsURL: String?
	private let guid: String?
	private let sourceName: String?
	private let sourceHomeURL: String?
	private let sourceFeedURL: String?

	public init(targetDescriptor: NSAppleEventDescriptor, title: String?, body: String?, summary: String?, link: String?, permalink: String?, subject: String?, creator: String?, commentsURL: String?, guid: String?, sourceName: String?, sourceHomeURL: String?, sourceFeedURL: String?) {
		self.targetDescriptor = targetDescriptor
		self.title = title
		self.body = body
		self.summary = summary
		self.link = link
		self.permalink = permalink
		self.subject = subject
		self.creator = creator
		self.commentsURL = commentsURL
		self.guid = guid
		self.sourceName = sourceName
		self.sourceHomeURL = sourceHomeURL
		self.sourceFeedURL = sourceFeedURL
	}


	/// Sends the receiver's data to the blog editor application described by `targetDescriptor`.
	public func send() {

		let appleEvent = NSAppleEventDescriptor(eventClass: .editDataItemAppleEventClass, eventID: .editDataItemAppleEventID, targetDescriptor: targetDescriptor, returnID: .autoGenerate, transactionID: .any)

		appleEvent.setParam(paramDescriptor, forKeyword: keyDirectObject)

		let _ = try? appleEvent.sendEvent(options: [.noReply, .canSwitchLayer, .alwaysInteract], timeout: .AEDefaultTimeout)

	}

}

private extension SendToBlogEditorApp {

	var paramDescriptor: NSAppleEventDescriptor {
		let descriptor = NSAppleEventDescriptor.record()

		add(toDescriptor: descriptor, value: title, keyword: .dataItemTitle)
		add(toDescriptor: descriptor, value: body, keyword: .dataItemDescription)
		add(toDescriptor: descriptor, value: summary, keyword: .dataItemSummary)
		add(toDescriptor: descriptor, value: link, keyword: .dataItemLink)
		add(toDescriptor: descriptor, value: permalink, keyword: .dataItemPermalink)
		add(toDescriptor: descriptor, value: subject, keyword: .dataItemSubject)
		add(toDescriptor: descriptor, value: creator, keyword: .dataItemCreator)
		add(toDescriptor: descriptor, value: commentsURL, keyword: .dataItemCommentsURL)
		add(toDescriptor: descriptor, value: guid, keyword: .dataItemGUID)
		add(toDescriptor: descriptor, value: sourceName, keyword: .dataItemSourceName)
		add(toDescriptor: descriptor, value: sourceHomeURL, keyword: .dataItemSourceHomeURL)
		add(toDescriptor: descriptor, value: sourceFeedURL, keyword: .dataItemSourceFeedURL)

		return descriptor
	}

	func add(toDescriptor descriptor: NSAppleEventDescriptor, value: String?, keyword: AEKeyword) {

		guard let value = value else { return }

		let stringDescriptor = NSAppleEventDescriptor.init(string: value)
		descriptor.setDescriptor(stringDescriptor, forKeyword: keyword)
	}
}

private extension AEEventClass {

	static let editDataItemAppleEventClass = "EBlg".fourCharCode

}

private extension AEEventID {

	static let editDataItemAppleEventID = "oitm".fourCharCode

}

private extension AEKeyword {

	static let dataItemTitle = "titl".fourCharCode
	static let dataItemDescription = "desc".fourCharCode
	static let dataItemSummary = "summ".fourCharCode
	static let dataItemLink = "link".fourCharCode
	static let dataItemPermalink = "plnk".fourCharCode
	static let dataItemSubject = "subj".fourCharCode
	static let dataItemCreator = "crtr".fourCharCode
	static let dataItemCommentsURL = "curl".fourCharCode
	static let dataItemGUID = "guid".fourCharCode
	static let dataItemSourceName = "snam".fourCharCode
	static let dataItemSourceHomeURL = "hurl".fourCharCode
	static let dataItemSourceFeedURL = "furl".fourCharCode

}

private extension AEReturnID {

	static let autoGenerate = AEReturnID(kAutoGenerateReturnID)
}

private extension AETransactionID {

	static let any = AETransactionID(kAnyTransactionID)

}

private extension TimeInterval {

	static let AEDefaultTimeout = TimeInterval(kAEDefaultTimeout)

}
#endif
