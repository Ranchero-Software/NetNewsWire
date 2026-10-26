//
//  TimelineCustomizerCollectionViewController.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 27/01/2026.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import UIKit
import Articles
import Images

class TimelineCustomizerCollectionViewController: UICollectionViewController {

	private enum Section: Int, CaseIterable {
		case iconSize
		case numberOfLines
		case options
		case noIconPreview
		case iconPreview
	}

	private enum OptionsRow: Int, CaseIterable {
		case feedIcons
		case thumbnails
	}

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
				contentText: "Bree was the chief village of Bree-land, a small country a few miles broad whose chief claim to fame was its aluminum siding industry. The Men of Bree were cheerful and independent: they belonged to nobody but themselves. In the lands beyond Bree there were mysterious wanderers.",
				markdown: nil,
				url: nil,
				externalURL: nil,
				summary: nil,
				imageURL: nil,
				thumbnailURL: nil,
				datePublished: date,
				dateModified: nil,
				authors: Set([Author(authorID: "_testAuthorID", name: "J. R. R. Tolkien", url: nil, avatarURL: nil, emailAddress: nil)!]),
				attachments: nil,
				status: ArticleStatus(articleID: "_testArticleID", read: false, starred: false, dateArrived: .now))
	}

	private var cachedTimelineLines: Int = AppDefaults.timelineNumberOfLines
	private var cachedIconSize: IconSize = AppDefaults.timelineIconSize

	// Created up front, since UIKit disallows creating a registration in cellForItemAt.
	private let optionsCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, OptionsRow> { cell, _, optionsRow in
		TimelineCustomizerCollectionViewController.configureOptionsCell(cell, optionsRow: optionsRow)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = NSLocalizedString("Timeline Layout", comment: "Timeline Layout")

		NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
			guard let self = self else { return }
			Task { @MainActor in

				if AppDefaults.timelineNumberOfLines != self.cachedTimelineLines {
					self.cachedTimelineLines = AppDefaults.timelineNumberOfLines
					self.userDefaultsDidChange()
				}

				if AppDefaults.timelineIconSize != self.cachedIconSize {
					self.cachedIconSize = AppDefaults.timelineIconSize
					self.userDefaultsDidChange()
				}
			}
		}
		NotificationCenter.default.addObserver(self, selector: #selector(handleTimelineFeedIconsDisplayDidChange(_:)), name: .timelineFeedIconsDisplayDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleTimelineThumbnailsDisplayDidChange(_:)), name: .timelineThumbnailsDisplayDidChange, object: nil)

		configureCollectionView()
	}

	private func configureCollectionView() {
		collectionView.register(
			TimelineHeaderView.self,
			forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
			withReuseIdentifier: TimelineHeaderView.reuseIdentifier
		)

		collectionView.register(MainTimelineCell.self, forCellWithReuseIdentifier: MainTimelineCell.reuseIdentifier)

		var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
		config.showsSeparators = false
		config.headerMode = .supplementary

		let layout = UICollectionViewCompositionalLayout.list(using: config)

		collectionView.setCollectionViewLayout(layout, animated: false)
	}

	// MARK: UICollectionViewDataSource

	override func numberOfSections(in collectionView: UICollectionView) -> Int {
		Section.allCases.count
	}

	override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		if Section(rawValue: section) == .options {
			return OptionsRow.allCases.count
		}
		return 1
	}

	override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

		switch Section(rawValue: indexPath.section) {
		case .iconSize:
			let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "IconSizeSelector", for: indexPath) as! TimelineCustomizerCell
			cell.sliderConfiguration = .iconSize
			return cell
		case .numberOfLines:
			let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NumberOfLinesSelector", for: indexPath) as! TimelineCustomizerCell
			cell.sliderConfiguration = .numberOfLines
			return cell
		case .options:
			let optionsRow = OptionsRow(rawValue: indexPath.item) ?? .feedIcons
			return collectionView.dequeueConfiguredReusableCell(using: optionsCellRegistration, for: indexPath, item: optionsRow)
		case .noIconPreview:
			return previewCell(showIcon: false, indexPath: indexPath)
		case .iconPreview:
			return previewCell(showIcon: true, indexPath: indexPath)
		case .none:
			return collectionView.dequeueReusableCell(withReuseIdentifier: MainTimelineCell.reuseIdentifier, for: indexPath)
		}
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

		switch Section(rawValue: indexPath.section) {
		case .iconSize:
			header.label.text = NSLocalizedString("Icon Size", comment: "Icon Size")
		case .numberOfLines:
			header.label.text = NSLocalizedString("Number of Lines", comment: "Number of Lines")
		case .noIconPreview:
			header.label.text = NSLocalizedString("No Icon Preview", comment: "No Icon Preview")
		case .iconPreview:
			header.label.text = NSLocalizedString("Icon Preview", comment: "Icon Preview")
		case .options, .none:
			header.label.text = nil
		}
		return header
	}

	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int
	) -> CGSize {
		CGSize(width: collectionView.bounds.width, height: 50)
	}

	override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
		switch Section(rawValue: indexPath.section) {
		case .iconSize, .numberOfLines:
			return true
		default:
			return false
		}
	}

	// MARK: Notifications

	func userDefaultsDidChange() {
		collectionView.reloadSections([Section.noIconPreview.rawValue, Section.iconPreview.rawValue])
	}

	@objc func handleTimelineFeedIconsDisplayDidChange(_ notification: Notification) {
		reconfigureOptionsRows()
	}

	@objc func handleTimelineThumbnailsDisplayDidChange(_ notification: Notification) {
		reconfigureOptionsRows()
	}
}

// MARK: - Private

private extension TimelineCustomizerCollectionViewController {

	func previewCell(showIcon: Bool, indexPath: IndexPath) -> MainTimelineCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MainTimelineCell.reuseIdentifier, for: indexPath) as! MainTimelineCell
		cell.cellData = MainTimelineCellData(article: previewArticle,
											 showFeedName: .byline,
											 feedName: "The Fellowship of the Ring",
											 byline: "J. R. R. Tolkien",
											 iconImage: IconImage(Assets.Images.nnwFeedIcon),
											 showIcon: showIcon,
											 numberOfLines: AppDefaults.timelineNumberOfLines,
											 iconSize: AppDefaults.timelineIconSize)
		cell.isPreview = true
		return cell
	}

	static private func configureOptionsCell(_ cell: UICollectionViewListCell, optionsRow: OptionsRow) {
		// The pop-up menu accessory shows only a chevron, so the value cell’s secondary text shows the current choice.
		var content = UIListContentConfiguration.valueCell()
		switch optionsRow {
		case .feedIcons:
			content.text = NSLocalizedString("Feed Icons", comment: "Feed Icons")
			content.secondaryText = AppDefaults.timelineFeedIconsDisplay.description
			cell.accessories = [.popUpMenu(timelineFeedIconsDisplayMenu())]
		case .thumbnails:
			content.text = NSLocalizedString("Thumbnail Size", comment: "Thumbnail Size")
			content.secondaryText = AppDefaults.timelineThumbnailsDisplay.description
			cell.accessories = [.popUpMenu(timelineThumbnailsDisplayMenu())]
		}
		cell.contentConfiguration = content

		// Matches TimelineCustomizerCell.
		cell.configurationUpdateHandler = { cell, state in
			var backgroundConfig = UIBackgroundConfiguration.listCell().updated(for: state)
			backgroundConfig.backgroundColor = cell.traitCollection.userInterfaceStyle == .dark ? .secondarySystemBackground : .white
			backgroundConfig.cornerRadius = 20
			cell.backgroundConfiguration = backgroundConfig
		}
	}

	static func timelineFeedIconsDisplayMenu() -> UIMenu {
		let currentFeedIconsDisplay = AppDefaults.timelineFeedIconsDisplay
		let actions = TimelineFeedIconsDisplay.allCases.map { feedIconsDisplay in
			UIAction(title: String(describing: feedIconsDisplay), subtitle: feedIconsDisplay.subtitle, state: feedIconsDisplay == currentFeedIconsDisplay ? .on : .off) { _ in
				AppDefaults.timelineFeedIconsDisplay = feedIconsDisplay
			}
		}
		return UIMenu(options: .singleSelection, children: actions)
	}

	static func timelineThumbnailsDisplayMenu() -> UIMenu {
		let currentThumbnailsDisplay = AppDefaults.timelineThumbnailsDisplay
		let actions = TimelineThumbnailsDisplay.allCases.map { thumbnailsDisplay in
			UIAction(title: String(describing: thumbnailsDisplay), state: thumbnailsDisplay == currentThumbnailsDisplay ? .on : .off) { _ in
				AppDefaults.timelineThumbnailsDisplay = thumbnailsDisplay
			}
		}
		return UIMenu(options: .singleSelection, children: actions)
	}

	func reconfigureOptionsRows() {
		let indexPaths = OptionsRow.allCases.map { IndexPath(item: $0.rawValue, section: Section.options.rawValue) }
		collectionView.reconfigureItems(at: indexPaths)
	}
}
