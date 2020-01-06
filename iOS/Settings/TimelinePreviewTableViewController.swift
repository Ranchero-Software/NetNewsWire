//
//  TimelinePreviewTableViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import Articles

class TimelinePreviewTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

	@IBOutlet weak var tableView: UITableView!
	
	override func viewDidLoad() {
        super.viewDidLoad()
		
		tableView.delegate = self
		tableView.dataSource = self
		
    }

	func heightFor(width: CGFloat) -> CGFloat {
		if UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory {
			let layout = MasterTimelineAccessibilityCellLayout(width: width, insets: tableView.safeAreaInsets, cellData: prototypeCellData)
			return layout.height
		} else {
			let layout = MasterTimelineDefaultCellLayout(width: width, insets: tableView.safeAreaInsets, cellData: prototypeCellData)
			return layout.height
		}
	}

	// MARK: - Table view data source

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! MasterTimelineTableViewCell
		cell.cellData = prototypeCellData
		return cell
	}
	
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
	}
	// MARK: API

	func reload() {
		tableView.reloadData()
	}

}

// MARK: Private

private extension TimelinePreviewTableViewController {

	var prototypeCellData: MasterTimelineCellData {
		let longTitle = "Enim ut tellus elementum sagittis vitae et. Nibh praesent tristique magna sit amet purus gravida quis blandit. Neque volutpat ac tincidunt vitae semper quis lectus nulla. Massa id neque aliquam vestibulum morbi blandit. Ultrices vitae auctor eu augue. Enim eu turpis egestas pretium aenean pharetra magna. Eget gravida cum sociis natoque. Sit amet consectetur adipiscing elit. Auctor eu augue ut lectus arcu bibendum. Maecenas volutpat blandit aliquam etiam erat velit. Ut pharetra sit amet aliquam id diam maecenas ultricies. In hac habitasse platea dictumst quisque sagittis purus sit amet."
		
		let prototypeID = "prototype"
		let status = ArticleStatus(articleID: prototypeID, read: false, starred: false, userDeleted: false, dateArrived: Date())
		let prototypeArticle = Article(accountID: prototypeID, articleID: prototypeID, webFeedID: prototypeID, uniqueID: prototypeID, title: longTitle, contentHTML: nil, contentText: nil, url: nil, externalURL: nil, summary: nil, imageURL: nil, datePublished: nil, dateModified: nil, authors: nil, status: status)
		
		let iconImage = IconImage(AppAssets.faviconTemplateImage.withTintColor(AppAssets.secondaryAccentColor))
		
		return MasterTimelineCellData(article: prototypeArticle, showFeedName: true, feedName: "Feed Name", iconImage: iconImage, showIcon: true, featuredImage: nil, numberOfLines: AppDefaults.timelineNumberOfLines, iconSize: AppDefaults.timelineIconSize)
	}
		
}
