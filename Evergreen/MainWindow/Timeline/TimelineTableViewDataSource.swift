//
//  TimelineTableViewDataSource.swift
//  Evergreen
//
//  Created by Brent Simmons on 10/29/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation

final class TimelineTableViewDataSource {

	private weak var timelineViewController: TimelineViewController?

	init(timelineViewController: TimelineViewController) {

		self.timelineViewController = timelineViewController
	}

	// MARK: NSTableViewDataSource

	func numberOfRows(in tableView: NSTableView) -> Int {

		return timelineViewController?.articles.count ? 0
	}

	func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {

		return timelineViewController?.articleAtRow(row) ? nil
	}

}
