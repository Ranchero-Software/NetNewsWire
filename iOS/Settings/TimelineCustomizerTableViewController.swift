//
//  TimelineCustomizerTableViewController.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 21/08/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import UIKit
import Articles

final class TimelineCustomizerTableViewController: UITableViewController {
	private var previewArticle: Article {
		var components = DateComponents()
		components.year = 1954
		components.month = 7
		components.day = 29

		let calendar = Calendar.current
		let date = calendar.date(from: components)!

		return Article(accountID: "_testID",
				articleID: "_testArticleID",
				feedID: "_testFeedID",
				uniqueID: UUID().uuidString,
				title: "At The Sign Of The Prancing Pony",
				contentHTML: nil,
				contentText: "Bree was the chief village of Bree-land, a small country a few miles broad whose chief claim to fame was its aluminum siding industry. The Men of Bree were cheerful and independant: they belonged to nobody but themselves. In the lands beyond Bree there were mysterious wanderers.",
				markdown: nil,
				url: nil,
				externalURL: nil,
				summary: nil,
				imageURL: nil,
				datePublished: date,
				dateModified: nil,
				authors: Set([Author(authorID: "_testAuthorID", name: "J. R. R. Tolkien", url: nil, avatarURL: nil, emailAddress: nil)!]),
				status: ArticleStatus(articleID: "_testArticleID", read: false, starred: false, dateArrived: .now))
	}

    override func viewDidLoad() {
        super.viewDidLoad()
		title = NSLocalizedString("Timeline Customizer", comment: "Timeline Customizer")

		NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
			Task { @MainActor in
				self?.userDefaultsDidChange()
			}
		}
    }

	override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
		tableView.reloadSections(IndexSet(integer: 2), with: .fade)
	}

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 1
    }

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		if section == 0 { return NSLocalizedString("Icon Size", comment: "Icon Size")}
		if section == 1 { return NSLocalizedString("Number of Lines", comment: "Number of Lines")}
		if section == 2 { return NSLocalizedString("Preview with Icon", comment: "Previews") }
		if section == 3 { return NSLocalizedString("Preview without Icon", comment: "Previews") }
		return nil
	}

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

		if indexPath.section == 0 {
			let cell = tableView.dequeueReusableCell(withIdentifier: "IconSizeCell") as! ModernTimelineSliderCell
			cell.sliderConfiguration = .iconSize
			return cell
		}

		if indexPath.section == 1 {
			let cell = tableView.dequeueReusableCell(withIdentifier: "NumberOfLinesCell") as! ModernTimelineSliderCell
			cell.sliderConfiguration = .numberOfLines
			return cell
		}

		if indexPath.section == 2 {
			let cell = tableView.dequeueReusableCell(withIdentifier: MainTimelineModernViewController.CellIdentifier.icon) as! MainTimelineCell
			cell.cellData = MainTimelineCellData(article: previewArticle,
												 showFeedName: .byline,
												 feedName: "The Fellowship of the Ring",
												 byline: "J. R. R. Tolkien",
												 iconImage: IconImage(Assets.Images.nnwFeedIcon),
												 showIcon: true,
												 numberOfLines: AppDefaults.shared.timelineNumberOfLines,
												 iconSize: AppDefaults.shared.timelineIconSize)
			cell.isPreview = true
			return cell
		}

		if indexPath.section == 3 {
			let cell = tableView.dequeueReusableCell(withIdentifier: MainTimelineModernViewController.CellIdentifier.standard) as! MainTimelineCell
			cell.cellData = MainTimelineCellData(article: previewArticle,
												 showFeedName: .byline,
												 feedName: "The Fellowship of the Ring",
												 byline: "J. R. R. Tolkien",
												 iconImage: nil,
												 showIcon: false,
												 numberOfLines: AppDefaults.shared.timelineNumberOfLines,
												 iconSize: AppDefaults.shared.timelineIconSize)
			cell.isPreview = true
			return cell
		}

		return UITableViewCell()

    }

	override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
		return nil
	}

	override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
		return false
	}

	// MARK: - Notifications

	func userDefaultsDidChange() {
		tableView.reloadSections(IndexSet(integersIn: 2...3), with: .none)
	}
}
