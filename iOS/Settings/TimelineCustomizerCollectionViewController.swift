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
		case preview
		case previewWithThumbnail
		case previewWithFeedIcon
		case previewWithFeedIconAndThumbnail

		static let previews: [Section] = [.preview, .previewWithThumbnail, .previewWithFeedIcon, .previewWithFeedIconAndThumbnail]

		var showsFeedIcon: Bool {
			self == .previewWithFeedIcon || self == .previewWithFeedIconAndThumbnail
		}

		var showsThumbnail: Bool {
			self == .previewWithThumbnail || self == .previewWithFeedIconAndThumbnail
		}
	}

	private enum OptionsRow: Int, CaseIterable {
		case feedIcons
		case thumbnails
		case fullTitles
		case fadeReadArticles
		case feedNameAndDateAboveTitle
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
	private let optionsCellRegistration = UICollectionView.CellRegistration<TimelineCustomizerOptionsCell, OptionsRow> { cell, _, optionsRow in
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
		NotificationCenter.default.addObserver(self, selector: #selector(handleTimelineShowFullTitlesDidChange(_:)), name: .timelineShowFullTitlesDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleTimelineFadeReadArticlesDidChange(_:)), name: .timelineFadeReadArticlesDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleTimelineFeedNameAndDateAboveTitleDidChange(_:)), name: .timelineFeedNameAndDateAboveTitleDidChange, object: nil)

		configureCollectionView()
	}

	private func configureCollectionView() {
		collectionView.register(
			TimelineHeaderView.self,
			forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
			withReuseIdentifier: TimelineHeaderView.reuseIdentifier
		)

		collectionView.register(MainTimelineCell.self, forCellWithReuseIdentifier: MainTimelineCell.reuseIdentifier)

		let layout = UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment in
			var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
			config.showsSeparators = false
			let isHidden = Self.isHidden(Section(rawValue: sectionIndex))
			config.headerMode = isHidden ? .none : .supplementary
			let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
			if isHidden {
				// An empty section still has insets, which would leave a gap.
				section.contentInsets = .zero
			}
			return section
		}

		collectionView.setCollectionViewLayout(layout, animated: false)
	}

	// MARK: UICollectionViewDataSource

	override func numberOfSections(in collectionView: UICollectionView) -> Int {
		Section.allCases.count
	}

	override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		let section = Section(rawValue: section)
		if Self.isHidden(section) {
			return 0
		}
		if section == .options {
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
			// The number of lines applies only to the title and summary.
			cell.slider.isEnabled = !AppDefaults.timelineShowFullTitles
			return cell
		case .options:
			let optionsRow = OptionsRow(rawValue: indexPath.item) ?? .feedIcons
			return collectionView.dequeueConfiguredReusableCell(using: optionsCellRegistration, for: indexPath, item: optionsRow)
		case .preview, .previewWithThumbnail, .previewWithFeedIcon, .previewWithFeedIconAndThumbnail:
			return previewCell(section: Section(rawValue: indexPath.section) ?? .preview, indexPath: indexPath)
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
		case .preview, .previewWithThumbnail, .previewWithFeedIcon, .previewWithFeedIconAndThumbnail:
			header.label.text = Self.previewHeaderTitle(Section(rawValue: indexPath.section) ?? .preview)
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
		reloadPreviews()
	}

	@objc func handleTimelineFeedIconsDisplayDidChange(_ notification: Notification) {
		reloadOptionsRowsAndPreviews()
	}

	@objc func handleTimelineThumbnailsDisplayDidChange(_ notification: Notification) {
		reloadOptionsRowsAndPreviews()
	}

	@objc func handleTimelineShowFullTitlesDidChange(_ notification: Notification) {
		collectionView.reloadSections(IndexSet(integer: Section.numberOfLines.rawValue))
		reloadOptionsRowsAndPreviews()
	}

	@objc func handleTimelineFadeReadArticlesDidChange(_ notification: Notification) {
		reloadOptionsRowsAndPreviews()
	}

	@objc func handleTimelineFeedNameAndDateAboveTitleDidChange(_ notification: Notification) {
		reloadOptionsRowsAndPreviews()
	}
}

// MARK: - Private

private extension TimelineCustomizerCollectionViewController {

	/// Hides a preview that the Feed Icons and Thumbnail Size settings mean would never be seen.
	/// Thumbnails don’t hide previews without one, since not every article has a thumbnail.
	static private func isHidden(_ section: Section?) -> Bool {
		guard let section, Section.previews.contains(section) else {
			return false
		}
		if section.showsThumbnail && AppDefaults.timelineThumbnailsDisplay == .none {
			return true
		}
		switch AppDefaults.timelineFeedIconsDisplay {
		case .automatic:
			return false
		case .always:
			return !section.showsFeedIcon
		case .never:
			return section.showsFeedIcon
		}
	}

	/// Names only what differs among the visible previews.
	static private func previewHeaderTitle(_ section: Section) -> String {
		let mentionsFeedIcon = section.showsFeedIcon && AppDefaults.timelineFeedIconsDisplay == .automatic
		switch (mentionsFeedIcon, section.showsThumbnail) {
		case (false, false):
			return NSLocalizedString("Preview", comment: "Preview")
		case (false, true):
			return NSLocalizedString("Preview with Thumbnail", comment: "Timeline Layout: header for the preview that shows a thumbnail")
		case (true, false):
			return NSLocalizedString("Preview with Feed Icon", comment: "Timeline Layout: header for the preview that shows a feed icon")
		case (true, true):
			return NSLocalizedString("Preview with Feed Icon and Thumbnail", comment: "Timeline Layout: header for the preview that shows a feed icon and a thumbnail")
		}
	}

	private func previewCell(section: Section, indexPath: IndexPath) -> MainTimelineCell {
		guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MainTimelineCell.reuseIdentifier, for: indexPath) as? MainTimelineCell else {
			assertionFailure("Expected MainTimelineCell")
			return MainTimelineCell()
		}
		cell.cellData = MainTimelineCellData(article: previewArticle,
											 showFeedName: .byline,
											 feedName: "The Fellowship of the Ring",
											 byline: "J. R. R. Tolkien",
											 iconImage: IconImage.nnwFeedIcon,
											 showIcon: section.showsFeedIcon,
											 numberOfLines: AppDefaults.timelineNumberOfLines,
											 iconSize: AppDefaults.timelineIconSize,
											 thumbnail: Assets.Images.timelinePreviewThumbnail,
											 showThumbnail: section.showsThumbnail,
											 thumbnailsDisplay: AppDefaults.timelineThumbnailsDisplay,
											 fadesReadArticles: AppDefaults.timelineFadeReadArticles,
											 feedNameAndDateAboveTitle: AppDefaults.timelineFeedNameAndDateAboveTitle,
											 showsFullTitles: AppDefaults.timelineShowFullTitles)
		cell.isPreview = true
		return cell
	}

	static private func configureOptionsCell(_ cell: TimelineCustomizerOptionsCell, optionsRow: OptionsRow) {
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
		case .fullTitles:
			content = UIListContentConfiguration.cell()
			content.text = NSLocalizedString("Full Titles, No Preview", comment: "Timeline Layout: switch that shows whole titles, without the article preview, in the timeline")
			configureSwitch(cell, isOn: AppDefaults.timelineShowFullTitles) { isOn in
				AppDefaults.timelineShowFullTitles = isOn
			}
		case .fadeReadArticles:
			content = UIListContentConfiguration.cell()
			content.text = NSLocalizedString("Fade Read Articles", comment: "Timeline Layout: switch that fades read articles in the timeline")
			configureSwitch(cell, isOn: AppDefaults.timelineFadeReadArticles) { isOn in
				AppDefaults.timelineFadeReadArticles = isOn
			}
		case .feedNameAndDateAboveTitle:
			content = UIListContentConfiguration.cell()
			content.text = NSLocalizedString("Feed Name and Date Above Title", comment: "Timeline Layout: switch that shows the feed name and date above the title in the timeline")
			configureSwitch(cell, isOn: AppDefaults.timelineFeedNameAndDateAboveTitle) { isOn in
				AppDefaults.timelineFeedNameAndDateAboveTitle = isOn
			}
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

	static func configureSwitch(_ cell: TimelineCustomizerOptionsCell, isOn: Bool, switchDidChange: @escaping (Bool) -> Void) {
		cell.switchControl.isOn = isOn
		cell.switchDidChange = switchDidChange
		cell.accessories = [.customView(configuration: .init(customView: cell.switchControl, placement: .trailing()))]
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

	func reloadPreviews() {
		collectionView.reloadSections(IndexSet(Section.previews.map(\.rawValue)))
	}

	/// One batch, since reconfiguring alone fails validation when a preview section’s item count has changed.
	func reloadOptionsRowsAndPreviews() {
		collectionView.performBatchUpdates {
			let indexPaths = OptionsRow.allCases.map { IndexPath(item: $0.rawValue, section: Section.options.rawValue) }
			collectionView.reconfigureItems(at: indexPaths)
			reloadPreviews()
		}
	}
}

// MARK: - TimelineCustomizerOptionsCell

/// Keeps one switch for the cell’s lifetime, since a new switch on every reconfigure animates into place.
final class TimelineCustomizerOptionsCell: UICollectionViewListCell {

	var switchDidChange: ((Bool) -> Void)?

	lazy var switchControl: UISwitch = {
		let switchControl = UISwitch()
		switchControl.addAction(UIAction { [weak self] _ in
			guard let self else {
				return
			}
			self.switchDidChange?(self.switchControl.isOn)
		}, for: .valueChanged)
		return switchControl
	}()
}
