//
//  TimelineTableViewDelegate.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/1/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Cocoa
import Data

@objc final class TimelineTableViewDelegate: NSObject, NSTableViewDelegate {

	private weak var timelineViewController: TimelineViewController?

	init(timelineViewController: TimelineViewController) {

		self.timelineViewController = timelineViewController
	}

	// MARK: NSTableViewDelegate

	func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {

		guard let timelineViewController = timelineViewController else {
			return nil
		}

		let rowView: TimelineTableRowView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "timelineRow"), owner: self) as! TimelineTableRowView
		rowView.cellAppearance = timelineViewController.cellAppearance
		return rowView
	}

	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

		guard let timelineViewController = timelineViewController else {
			return nil
		}

		let cell: TimelineTableCellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "timelineCell"), owner: self) as! TimelineTableCellView
		cell.cellAppearance = timelineViewController.cellAppearance

		if let article = timelineViewController.articles.articleAtRow(row) {
			configureTimelineCell(cell, article: article)
		}
		else {
			makeTimelineCellEmpty(cell)
		}

		return cell
	}

	private func postTimelineSelectionDidChangeNotification(_ selectedArticle: Article?) {

		guard let timelineViewController = timelineViewController else {
			return
		}

		let appInfo = AppInfo()
		if let article = selectedArticle {
			appInfo.article = article
		}
		appInfo.view = timelineViewController.tableView

		NotificationCenter.default.post(name: .TimelineSelectionDidChange, object: timelineViewController, userInfo: appInfo.userInfo)
	}

	func tableViewSelectionDidChange(_ notification: Notification) {

		guard let timelineViewController = timelineViewController, let tableView = timelineViewController.tableView else {
			return
		}

		tableView.redrawGrid()

		let selectedRow = tableView.selectedRow
		if selectedRow < 0 || selectedRow == NSNotFound || tableView.numberOfSelectedRows != 1 {
			postTimelineSelectionDidChangeNotification(nil)
			return
		}

		if let selectedArticle = timelineViewController.articles.articleAtRow(selectedRow) {
			if (!selectedArticle.status.read) {
				markArticles(Set([selectedArticle]), statusKey: .read, flag: true)
			}
			postTimelineSelectionDidChangeNotification(selectedArticle)
		}
		else {
			postTimelineSelectionDidChangeNotification(nil)
		}
	}

}

private extension TimelineTableViewDelegate {

	func configureTimelineCell(_ cell: TimelineTableCellView, article: Article) {

		guard let timelineViewController = timelineViewController else {
			return
		}

		cell.objectValue = article
		cell.cellData = TimelineCellData(article: article, appearance: timelineViewController.cellAppearance, showFeedName: timelineViewController.showFeedNames)
	}

	func makeTimelineCellEmpty(_ cell: TimelineTableCellView) {

		cell.objectValue = nil
		cell.cellData = emptyCellData
	}
}
