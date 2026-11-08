//
//  TimelinePreferencesViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/7/26.
//

import AppKit
import RSCore
import Images

final class TimelinePreferencesViewController: NSViewController {

	@IBOutlet var timelineIconsPopup: NSPopUpButton?
	@IBOutlet var timelineIconSizePopup: NSPopUpButton?
	@IBOutlet var timelineTitleAndSummaryButton: NSButton?
	@IBOutlet var timelineNumberOfLinesPopup: NSPopUpButton?
	@IBOutlet var timelineFullTitlesButton: NSButton?
	@IBOutlet var timelineThumbnailsPopup: NSPopUpButton?
	@IBOutlet var timelineTextSizePopup: NSPopUpButton?
	@IBOutlet var timelineShowSeparatorsButton: NSButton?
	@IBOutlet var timelineFadeReadArticlesButton: NSButton?
	@IBOutlet var timelineFeedNameAndDateAboveTitleButton: NSButton?

	convenience init() {
		self.init(nibName: "TimelinePreferencesView", bundle: nil)
	}

	override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
		super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
		commonInit()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		view.sizeToFittingSize()
	}

	override func viewWillAppear() {
		super.viewWillAppear()
		updateTimelineFeedIconsPopup()
		updateTimelineIconSizePopup()
		updateTimelineThumbnailsPopup()
		updateTimelineTextSizePopup()
		updateTimelineRowsControls()
		updateTimelineShowSeparatorsButton()
		updateTimelineFadeReadArticlesButton()
		updateTimelineFeedNameAndDateAboveTitleButton()
	}

	// MARK: - Notifications

	@objc func handleTimelineFeedIconsDisplayDidChange(_ notification: Notification) {
		updateTimelineFeedIconsPopup()
	}

	@objc func handleTimelineIconSizeDidChange(_ notification: Notification) {
		updateTimelineIconSizePopup()
	}

	@objc func handleTimelineThumbnailsDisplayDidChange(_ notification: Notification) {
		updateTimelineThumbnailsPopup()
	}

	@objc func handleTimelineTextSizeDidChange(_ notification: Notification) {
		updateTimelineTextSizePopup()
	}

	@objc func handleTimelineNumberOfLinesDidChange(_ notification: Notification) {
		updateTimelineRowsControls()
	}

	@objc func handleTimelineShowFullTitlesDidChange(_ notification: Notification) {
		updateTimelineRowsControls()
	}

	@objc func handleTimelineShowSeparatorsDidChange(_ notification: Notification) {
		updateTimelineShowSeparatorsButton()
	}

	@objc func handleTimelineFadeReadArticlesDidChange(_ notification: Notification) {
		updateTimelineFadeReadArticlesButton()
	}

	@objc func handleTimelineFeedNameAndDateAboveTitleDidChange(_ notification: Notification) {
		updateTimelineFeedNameAndDateAboveTitleButton()
	}

	// MARK: - Actions

	@IBAction func timelineFeedIconsPopUpDidChange(_ sender: Any) {
		guard let tag = timelineIconsPopup?.selectedTag(), let feedIconsDisplay = TimelineFeedIconsDisplay(rawValue: tag) else {
			return
		}
		AppDefaults.timelineFeedIconsDisplay = feedIconsDisplay
	}

	@IBAction func timelineIconSizePopUpDidChange(_ sender: Any) {
		guard let tag = timelineIconSizePopup?.selectedTag(), let iconSize = IconSize(rawValue: tag) else {
			return
		}
		AppDefaults.timelineIconSize = iconSize
	}

	@IBAction func timelineThumbnailsPopUpDidChange(_ sender: Any) {
		guard let tag = timelineThumbnailsPopup?.selectedTag(), let thumbnailsDisplay = TimelineThumbnailsDisplay(rawValue: tag) else {
			return
		}
		AppDefaults.timelineThumbnailsDisplay = thumbnailsDisplay
	}

	@IBAction func timelineTextSizePopUpDidChange(_ sender: Any) {
		guard let tag = timelineTextSizePopup?.selectedTag(), let textSize = TimelineTextSize(rawValue: tag) else {
			return
		}
		AppDefaults.timelineTextSize = textSize
	}

	@IBAction func timelineNumberOfLinesPopUpDidChange(_ sender: Any) {
		guard let numberOfLines = timelineNumberOfLinesPopup?.selectedTag() else {
			return
		}
		AppDefaults.timelineNumberOfLines = numberOfLines
	}

	@IBAction func timelineRowsRadioButtonDidChange(_ sender: NSButton) {
		AppDefaults.timelineShowFullTitles = sender === timelineFullTitlesButton
	}

	@IBAction func timelineShowSeparatorsDidChange(_ sender: NSButton) {
		AppDefaults.timelineShowSeparators = sender.state == .on
	}

	@IBAction func timelineFadeReadArticlesDidChange(_ sender: NSButton) {
		AppDefaults.timelineFadeReadArticles = sender.state == .on
	}

	@IBAction func timelineFeedNameAndDateAboveTitleDidChange(_ sender: NSButton) {
		AppDefaults.timelineFeedNameAndDateAboveTitle = sender.state == .on
	}
}

// MARK: - Private

private extension TimelinePreferencesViewController {

	func commonInit() {
		NotificationCenter.default.addObserver(self, selector: #selector(handleTimelineFeedIconsDisplayDidChange(_:)), name: .timelineFeedIconsDisplayDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleTimelineIconSizeDidChange(_:)), name: .timelineIconSizeDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleTimelineThumbnailsDisplayDidChange(_:)), name: .timelineThumbnailsDisplayDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleTimelineTextSizeDidChange(_:)), name: .timelineTextSizeDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleTimelineNumberOfLinesDidChange(_:)), name: .timelineNumberOfLinesDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleTimelineShowFullTitlesDidChange(_:)), name: .timelineShowFullTitlesDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleTimelineShowSeparatorsDidChange(_:)), name: .timelineShowSeparatorsDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleTimelineFadeReadArticlesDidChange(_:)), name: .timelineFadeReadArticlesDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleTimelineFeedNameAndDateAboveTitleDidChange(_:)), name: .timelineFeedNameAndDateAboveTitleDidChange, object: nil)
	}

	func updateTimelineFeedIconsPopup() {
		timelineIconsPopup?.selectItem(withTag: AppDefaults.timelineFeedIconsDisplay.rawValue)
	}

	func updateTimelineIconSizePopup() {
		timelineIconSizePopup?.selectItem(withTag: AppDefaults.timelineIconSize.rawValue)
	}

	func updateTimelineThumbnailsPopup() {
		timelineThumbnailsPopup?.selectItem(withTag: AppDefaults.timelineThumbnailsDisplay.rawValue)
	}

	func updateTimelineTextSizePopup() {
		timelineTextSizePopup?.selectItem(withTag: AppDefaults.timelineTextSize.rawValue)
	}

	/// The number of lines applies only to title and summary, so its popup is disabled with full titles.
	func updateTimelineRowsControls() {
		let showFullTitles = AppDefaults.timelineShowFullTitles
		timelineTitleAndSummaryButton?.state = showFullTitles ? .off : .on
		timelineFullTitlesButton?.state = showFullTitles ? .on : .off
		timelineNumberOfLinesPopup?.selectItem(withTag: AppDefaults.timelineNumberOfLines)
		timelineNumberOfLinesPopup?.isEnabled = !showFullTitles
	}

	func updateTimelineShowSeparatorsButton() {
		timelineShowSeparatorsButton?.state = AppDefaults.timelineShowSeparators ? .on : .off
	}

	func updateTimelineFadeReadArticlesButton() {
		timelineFadeReadArticlesButton?.state = AppDefaults.timelineFadeReadArticles ? .on : .off
	}

	func updateTimelineFeedNameAndDateAboveTitleButton() {
		timelineFeedNameAndDateAboveTitleButton?.state = AppDefaults.timelineFeedNameAndDateAboveTitle ? .on : .off
	}
}
