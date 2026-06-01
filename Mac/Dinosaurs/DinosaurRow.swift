//
//  DinosaurRow.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 5/31/26.
//

import Account

struct DinosaurRow: Identifiable {

	let id: String
	let feed: Feed
	let account: Account
	let accountName: String
	let feedName: String
	let feedURL: String
	let lastArticleDate: Date?
	let lastResponseCode: Int?
}
