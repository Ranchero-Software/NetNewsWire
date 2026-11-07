//
//  AppearancePreferencesViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/6/26.
//

import AppKit
import RSCore
import Images

final class AppearancePreferencesViewController: NSViewController {

	@IBOutlet var appearancePopup: NSPopUpButton?

	@IBOutlet var sidebarShowFeedIconsButton: NSButton?
	@IBOutlet var sidebarTextSizePopup: NSPopUpButton?
	@IBOutlet var sidebarShowTodayButton: NSButton?
	@IBOutlet var sidebarShowAllUnreadButton: NSButton?
	@IBOutlet var sidebarShowStarredButton: NSButton?

	@IBOutlet var timelineIconsPopup: NSPopUpButton?
	@IBOutlet var timelineIconSizePopup: NSPopUpButton?
	@IBOutlet var timelineTitleAndSummaryButton: NSButton?
	@IBOutlet var timelineNumberOfLinesPopup: NSPopUpButton?
	@IBOutlet var timelineFullTitlesButton: NSButton?
	@IBOutlet var timelineThumbnailsPopup: NSPopUpButton?
	@IBOutlet var timelineTextSizePopup: NSPopUpButton?
	@IBOutlet var timelineShowSeparatorsButton: NSButton?
	@IBOutlet var timelineFadeReadArticlesButton: NSButton?

	@IBOutlet var articleTextSizeLabel: NSTextField?
	@IBOutlet var articleTextSizePopup: NSPopUpButton?
	@IBOutlet var articleThemePopup: NSPopUpButton?

	convenience init() {
		self.init(nibName: "AppearancePreferencesView", bundle: nil)
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
		fixArticleTextSizeBaselineIfNeeded()
		view.sizeToFittingSize()
	}

	override func viewWillAppear() {
		super.viewWillAppear()
		updateAppearancePopup()
		updateSidebarShowIconsButton()
		updateSidebarTextSizePopup()
		updateSmartFeedsButtons()
		updateTimelineFeedIconsPopup()
		updateTimelineIconSizePopup()
		updateTimelineThumbnailsPopup()
		updateTimelineTextSizePopup()
		updateTimelineRowsControls()
		updateTimelineShowSeparatorsButton()
		updateTimelineFadeReadArticlesButton()
		updateArticleThemePopup()
	}

	// MARK: - Notifications

	@objc func handleApplicationWillBecomeActive(_ notification: Notification) {
		updateArticleThemePopup()
	}

	@objc func handleArticleThemeNamesDidChange(_ notification: Notification) {
		updateArticleThemePopup()
	}

	@objc func handleUserInterfaceColorPaletteDidUpdate(_ notification: Notification) {
		updateAppearancePopup()
	}

	@objc func handleSidebarShowsIconsDidChange(_ notification: Notification) {
		updateSidebarShowIconsButton()
	}

	@objc func handleSidebarTextSizeDidChange(_ notification: Notification) {
		updateSidebarTextSizePopup()
	}

	@objc func handleSidebarSmartFeedsVisibilityDidChange(_ notification: Notification) {
		updateSmartFeedsButtons()
	}

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

	// MARK: - Actions

	@IBAction func appearancePopUpDidChange(_ sender: Any) {
		guard let tag = appearancePopup?.selectedTag(), let colorPalette = UserInterfaceColorPalette(rawValue: tag) else {
			return
		}
		AppDefaults.userInterfaceColorPalette = colorPalette
	}

	@IBAction func sidebarShowIconsDidChange(_ sender: NSButton) {
		AppDefaults.sidebarShowsIcons = sender.state == .on
	}

	@IBAction func sidebarTextSizePopUpDidChange(_ sender: Any) {
		guard let tag = sidebarTextSizePopup?.selectedTag(), let textSize = SidebarTextSize(rawValue: tag) else {
			return
		}
		AppDefaults.sidebarTextSize = textSize
	}

	@IBAction func sidebarShowTodayDidChange(_ sender: NSButton) {
		AppDefaults.showTodayFeed = sender.state == .on
	}

	@IBAction func sidebarShowAllUnreadDidChange(_ sender: NSButton) {
		AppDefaults.showUnreadFeed = sender.state == .on
	}

	@IBAction func sidebarShowStarredDidChange(_ sender: NSButton) {
		AppDefaults.showStarredFeed = sender.state == .on
	}

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

	@IBAction func showThemesFolder(_ sender: Any) {
		let url = URL(fileURLWithPath: ArticleThemesManager.shared.folderPath)
		NSWorkspace.shared.open(url)
	}

	@IBAction func articleThemePopUpDidChange(_ sender: Any) {
		guard let menuItem = articleThemePopup?.selectedItem else {
			return
		}
		ArticleThemesManager.shared.currentThemeName = menuItem.title
		updateArticleThemePopup()
	}
}

// MARK: - Private

private extension AppearancePreferencesViewController {

	func commonInit() {
		NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationWillBecomeActive(_:)), name: NSApplication.willBecomeActiveNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleArticleThemeNamesDidChange(_:)), name: .ArticleThemeNamesDidChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleUserInterfaceColorPaletteDidUpdate(_:)), name: .userInterfaceColorPaletteDidUpdate, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleSidebarShowsIconsDidChange(_:)), name: .sidebarShowsIconsDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleSidebarTextSizeDidChange(_:)), name: .sidebarTextSizeDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleSidebarSmartFeedsVisibilityDidChange(_:)), name: .sidebarSmartFeedsVisibilityDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleTimelineFeedIconsDisplayDidChange(_:)), name: .timelineFeedIconsDisplayDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleTimelineIconSizeDidChange(_:)), name: .timelineIconSizeDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleTimelineThumbnailsDisplayDidChange(_:)), name: .timelineThumbnailsDisplayDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleTimelineTextSizeDidChange(_:)), name: .timelineTextSizeDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleTimelineNumberOfLinesDidChange(_:)), name: .timelineNumberOfLinesDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleTimelineShowFullTitlesDidChange(_:)), name: .timelineShowFullTitlesDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleTimelineShowSeparatorsDidChange(_:)), name: .timelineShowSeparatorsDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleTimelineFadeReadArticlesDidChange(_:)), name: .timelineFadeReadArticlesDidChange, object: nil)
	}

	/// On macOS 15 the "Article Text Size:" label is vertically misaligned
	/// with its popup. Replace the firstBaseline constraint with a
	/// centerY constraint, which works.
	func fixArticleTextSizeBaselineIfNeeded() {
		if #available(macOS 26, *) {
			return
		}

		guard let articleTextSizeLabel, let articleTextSizePopup, let superview = articleTextSizeLabel.superview else {
			return
		}

		for constraint in superview.constraints {
			let matchesBaseline =
				constraint.firstAttribute == .firstBaseline &&
				constraint.secondAttribute == .firstBaseline
			let involvesPopup =
				constraint.firstItem === articleTextSizePopup ||
				constraint.secondItem === articleTextSizePopup
			let involvesLabel =
				constraint.firstItem === articleTextSizeLabel ||
				constraint.secondItem === articleTextSizeLabel

			if matchesBaseline && involvesPopup && involvesLabel {
				superview.removeConstraint(constraint)
				articleTextSizeLabel.centerYAnchor.constraint(equalTo: articleTextSizePopup.centerYAnchor).isActive = true
				break
			}
		}
	}

	func updateAppearancePopup() {
		appearancePopup?.selectItem(withTag: AppDefaults.userInterfaceColorPalette.rawValue)
	}

	func updateSidebarShowIconsButton() {
		sidebarShowFeedIconsButton?.state = AppDefaults.sidebarShowsIcons ? .on : .off
	}

	func updateSidebarTextSizePopup() {
		sidebarTextSizePopup?.selectItem(withTag: AppDefaults.sidebarTextSize.rawValue)
	}

	func updateSmartFeedsButtons() {
		sidebarShowTodayButton?.state = AppDefaults.showTodayFeed ? .on : .off
		sidebarShowAllUnreadButton?.state = AppDefaults.showUnreadFeed ? .on : .off
		sidebarShowStarredButton?.state = AppDefaults.showStarredFeed ? .on : .off
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

	func updateArticleThemePopup() {
		guard let articleThemePopup, let menu = articleThemePopup.menu else {
			return
		}
		menu.removeAllItems()

		menu.addItem(NSMenuItem(title: ArticleTheme.defaultTheme.name, action: nil, keyEquivalent: ""))
		menu.addItem(NSMenuItem.separator())

		for themeName in ArticleThemesManager.shared.themeNames {
			menu.addItem(NSMenuItem(title: themeName, action: nil, keyEquivalent: ""))
		}

		articleThemePopup.selectItem(withTitle: ArticleThemesManager.shared.currentThemeName)
		if articleThemePopup.indexOfSelectedItem == -1 {
			articleThemePopup.selectItem(withTitle: ArticleTheme.defaultTheme.name)
		}
	}
}
