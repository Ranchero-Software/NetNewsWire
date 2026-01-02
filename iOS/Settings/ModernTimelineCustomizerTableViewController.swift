//
//  ModernTimelineCustomizerTableViewController.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 21/08/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import UIKit
import Articles

final class ModernTimelineCustomizerTableViewController: UITableViewController {
	private var previewArticle: Article {
		var components = DateComponents()
		components.year = 1925
		components.month = 4
		components.day = 10

		let calendar = Calendar.current
		let date = calendar.date(from: components)!

		return Article(accountID: "_testID",
				articleID: "_testArticleID",
				feedID: "_testFeedID",
				uniqueID: UUID().uuidString,
				title: "Chapter 1",
				contentHTML: nil,
				contentText: "In my younger and more vulnerable years my father gave me some advice that I’ve been turning over in my mind ever since. “Whenever you feel like criticizing any one,” he told me, “just remember that all the people in this world haven’t had the advantages that you’ve had.”",
				markdown: nil,
				url: nil,
				externalURL: nil,
				summary: nil,
				imageURL: nil,
				datePublished: date,
				dateModified: nil,
				authors: Set([Author(authorID: "_testAuthorID", name: "F. Scott Fitzgerald", url: nil, avatarURL: nil, emailAddress: nil)!]),
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
			let cell = tableView.dequeueReusableCell(withIdentifier: "MainTimelineIconFeedCell") as? MainTimelineIconFeedCell ?? MainTimelineIconFeedCell()
			cell.cellData = MainTimelineCellData(article: previewArticle,
												 showFeedName: .byline,
												 feedName: "The Great Gatsby",
												 byline: "F. Scott Fitzgerald",
												 iconImage: IconImage(Assets.Images.nnwFeedIcon),
												 showIcon: true,
												 numberOfLines: AppDefaults.shared.timelineNumberOfLines,
												 iconSize: AppDefaults.shared.timelineIconSize)
			cell.isPreview = true
			return cell
		}

		if indexPath.section == 3 {
			let cell = tableView.dequeueReusableCell(withIdentifier: "MainTimelineFeedCell") as? MainTimelineFeedCell ?? MainTimelineFeedCell()
			cell.cellData = MainTimelineCellData(article: previewArticle,
												 showFeedName: .byline,
												 feedName: "The Great Gatsby",
												 byline: "F. Scott Fitzgerald",
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
