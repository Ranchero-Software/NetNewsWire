//
//  FeedbinAccount.swift
//  Feedbin
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import DataModel

public let feedbinAccountType = "Feedbin"

public final class FeedbinAccount: Account, PlistProvider {

	public let identifier: String
	public let type = feedbinAccountType
	public var nameForDisplay = "Feedbin"

	private let settingsFile: String
	private let dataFolder: String
	private let diskSaver: DiskSaver
	fileprivate let database: FeedbinDatabase
	fileprivate var feeds = Set<FeedbinFeed>()

	public var account: Account? {
		get {
			return self
		}
	}

	public var unreadCount = 0 {
		didSet {
			postUnreadCountDidChangeNotification()
		}
	}

	required public init(settingsFile: String, dataFolder: String, identifier: String) {

		self.settingsFile = settingsFile
		self.dataFolder = dataFolder
		self.identifier = identifier

		let databaseFile = (dataFolder as NSString).appendingPathComponent("FeedbinArticles0.db")
		self.localDatabase = FeedbinDatabase(databaseFile: databaseFile)
		self.diskSaver = DiskSaver(path: settingsFile)

		self.localDatabase.account = self
		self.diskSaver.delegate = self
		self.refresher.account = self

		pullSettingsAndTopLevelItemsFromFile()

		self.database.startup()

		updateUnreadCountsForTopLevelFolders()
		updateUnreadCount()

		NotificationCenter.default.addObserver(self, selector: #selector(articleStatusesDidChange(_:)), name: .ArticleStatusesDidChange, object: nil)

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)

		NotificationCenter.default.addObserver(self, selector: #selector(refreshProgressDidChange(_:)), name: .DownloadProgressDidChange, object: nil)

		DispatchQueue.main.async() { () -> Void in
			self.updateUnreadCounts(feedIDs: self.flattenedFeedIDs)
		}
	}

}
