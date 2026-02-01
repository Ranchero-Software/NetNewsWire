//
//  TimelineCustomizerCollectionViewController.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 27/01/2026.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import UIKit
import Articles

class TimelineCustomizerCollectionViewController: UICollectionViewController {
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

	private var cachedTimelineLines: Int = AppDefaults.shared.timelineNumberOfLines
	private var cachedIconSize: IconSize = AppDefaults.shared.timelineIconSize

    override func viewDidLoad() {
        super.viewDidLoad()
		title = NSLocalizedString("Timeline Customizer", comment: "Timeline Customizer")

		NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
			guard let self = self else { return }
			Task { @MainActor in

				if AppDefaults.shared.timelineNumberOfLines != self.cachedTimelineLines {
					self.cachedTimelineLines = AppDefaults.shared.timelineNumberOfLines
					self.userDefaultsDidChange()
				}

				if AppDefaults.shared.timelineIconSize != self.cachedIconSize {
					self.cachedIconSize = AppDefaults.shared.timelineIconSize
					self.userDefaultsDidChange()
				}
			}
		}

		configureCollectionView()
    }

	private func configureCollectionView() {
		collectionView.register(
			TimelineHeaderView.self,
			forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
			withReuseIdentifier: TimelineHeaderView.reuseIdentifier
		)

		var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
		config.showsSeparators = false
		config.headerMode = .supplementary

		let layout = UICollectionViewCompositionalLayout.list(using: config)

		collectionView.setCollectionViewLayout(layout, animated: false)
	}

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 4
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of items
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

		if indexPath.section == 0 {
			let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "IconSizeSelector", for: indexPath) as! TimelineCustomizerCell
			cell.sliderConfiguration = .iconSize
			return cell
		}

		if indexPath.section == 1 {
			let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NumberOfLinesSelector", for: indexPath) as! TimelineCustomizerCell
			cell.sliderConfiguration = .numberOfLines
			return cell
		}

		if indexPath.section == 2 {
			let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MainTimelineCellStandard", for: indexPath) as! MainTimelineCollectionViewCell
			cell.cellData = MainTimelineCellData(article: previewArticle,
												 showFeedName: .byline,
												 feedName: "The Fellowship of the Ring",
												 byline: "J. R. R. Tolkien",
												 iconImage: IconImage(Assets.Images.nnwFeedIcon),
												 showIcon: false,
												 numberOfLines: AppDefaults.shared.timelineNumberOfLines,
												 iconSize: AppDefaults.shared.timelineIconSize)
			cell.isPreview = true
			return cell
		}

		if indexPath.section == 3 {
			let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MainTimelineCellIcon", for: indexPath) as! MainTimelineCollectionViewCell
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

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MainTimelineCellStandard", for: indexPath)
        return cell
    }

	// MARK: UICollectionViewDelegate

	override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath
	) -> UICollectionReusableView {

		guard kind == UICollectionView.elementKindSectionHeader else {
			return UICollectionReusableView()
		}

		let header = collectionView.dequeueReusableSupplementaryView(
			ofKind: kind,
			withReuseIdentifier: TimelineHeaderView.reuseIdentifier,
			for: indexPath
		) as! TimelineHeaderView

		switch indexPath.section {
		case 0:
			header.label.text = NSLocalizedString("Icon Size", comment: "Icon Size")
		case 1:
			header.label.text = NSLocalizedString("Number of Lines", comment: "Number of Lines")
		case 2:
			header.label.text = NSLocalizedString("No Icon Preview", comment: "No Icon Preview")
		case 3:
			header.label.text = NSLocalizedString("Icon Preview", comment: "Icon Preview")
		default:
			header.label.text = NSLocalizedString("", comment: "")
		}
		return header
	}

	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int
	) -> CGSize {
		CGSize(width: collectionView.bounds.width, height: 50)
	}

	override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
		if indexPath.section > 1 {
			return false
		}
		return true
	}

	// MARK: Notifications

	func userDefaultsDidChange() {
		collectionView.reloadSections([2, 3])
	}

}
