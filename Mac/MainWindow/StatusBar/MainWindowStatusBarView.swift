//
//  MainWindowStatusBarView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/11/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import AppKit
import Account
import RSCore

@MainActor protocol MainWindowStatusBarViewDelegate: AnyObject {
	func statusBarViewGearMenu(_ statusBarView: MainWindowStatusBarView) -> NSMenu?
	/// `position` is in the status bar’s coordinates.
	func statusBarView(_ statusBarView: MainWindowStatusBarView, moveSidebarDividerTo position: CGFloat)
}

/// The bar along the bottom of the main window: gear menu, count, sidebar grip, article link, theme menu.
/// The left section lines up with the sidebar, and the sidebar divider continues down through the bar. Dragging at the divider moves it.
/// Subviews are laid out manually in `layout()`.
final class MainWindowStatusBarView: NSView {

	weak var delegate: MainWindowStatusBarViewDelegate?

	/// The link to show — the hovered link or the selected article’s link.
	var link: String? {
		didSet {
			if link != oldValue {
				updateLinkLabel()
			}
		}
	}

	/// Where the split view draws the divider line, relative to `sidebarDividerPosition`, and how wide.
	/// The line through the bar uses these so it lines up with the divider above it.
	var sidebarDividerLineOffset: CGFloat = 0 {
		didSet {
			needsDisplay = true
		}
	}
	var sidebarDividerLineWidth: CGFloat = 1 {
		didSet {
			needsDisplay = true
		}
	}

	/// The sidebar divider’s x position in this view’s coordinates, or nil when the sidebar is collapsed.
	var sidebarDividerPosition: CGFloat? {
		didSet {
			if sidebarDividerPosition != oldValue {
				// With the sidebar collapsed, the left section is just the gear and progress.
				splitHandleView.isHidden = sidebarDividerPosition == nil
				countLabel.isHidden = sidebarDividerPosition == nil
				needsLayout = true
				needsDisplay = true
			}
		}
	}

	// Measured from the mockup: 32 points including the top line.
	static let height: CGFloat = 32

	private let gearButton = StatusBarGearButton()
	private let progressIndicator = NSProgressIndicator()
	private let countLabel = NSTextField(labelWithString: "")
	private let splitHandleView = StatusBarSplitHandleView()
	private let linkLabel = NSTextField(labelWithString: "")
	private let themePopUpButton = NSPopUpButton(frame: .zero, pullsDown: false)
	private var dragStartDividerPosition: CGFloat?

	private static let fontSize: CGFloat = 12
	private static let topLineThickness: CGFloat = 1
	private static let leadingMargin: CGFloat = 15
	// The standard window-edge margin, applied to the theme pop-up button’s alignment rect. It keeps the
	// button clear of the window’s bottom-right resize area.
	private static let trailingMargin: CGFloat = 20
	private static let spacingAfterGear: CGFloat = 12
	// The count’s clickable area ends this far before the sidebar’s edge.
	private static let countClickAreaTrailingInset: CGFloat = 20
	// With the sidebar collapsed, the left section ends this far after its last item.
	private static let leftSectionTrailingInsetWithoutSidebar: CGFloat = 6
	private static let progressSpacing: CGFloat = 6
	// The text field has its own inset, so the link’s text starts 13 points after the divider.
	private static let spacingAfterDivider: CGFloat = 12.5
	private static let spacingBeforeThemeMenu: CGFloat = 8
	private static let progressIndicatorWidth: CGFloat = 40

	private static let topLineColor = dynamicColor(lightWhite: 224 / 255, darkWhite: 0.1)
	// Lighter than the grip, close to the system’s sidebar divider above the bar.
	private static let dividerColor = dynamicColor(lightWhite: 204 / 255, darkWhite: 0.28)
	private static let gripColor = dynamicColor(lightWhite: 180 / 255, darkWhite: 0.35)

	// The ||| grip: three hairlines, the last one 6.5 points before the divider.
	private static let gripLineCount = 3
	private static let gripLineInterval: CGFloat = 5
	private static let gripLineHeight: CGFloat = 12
	private static let gripTrailingInset: CGFloat = 6.5
	// The drag area covers the grip and extends past the divider.
	private static let dragAreaReachBeforeDivider: CGFloat = 17
	private static let dragAreaReachAfterDivider: CGFloat = 6
	private static let textColor = dynamicColor(lightWhite: 44 / 255, darkWhite: 0.85)
	private static let gradient = NSGradient(starting: dynamicColor(lightWhite: 217 / 255, darkWhite: 0.17), ending: dynamicColor(lightWhite: 242 / 255, darkWhite: 0.22))
	// Bottom to top, so the gradient starts with the darker color at the bottom.
	private static let gradientAngle: CGFloat = 90

	/// The etched look: a light line just below the text and icons. In dark mode, a dark line.
	static let etchedShadow: NSShadow = {
		let shadow = NSShadow()
		shadow.shadowOffset = NSSize(width: 0, height: -1)
		shadow.shadowBlurRadius = 0
		shadow.shadowColor = NSColor(name: nil) { appearance in
			isDark(appearance) ? NSColor(white: 0, alpha: 0.5) : NSColor(white: 1, alpha: 0.65)
		}
		return shadow
	}()

	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		commonInit()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}

	override var isOpaque: Bool {
		true
	}

	override func layout() {
		super.layout()

		// The content area is everything below the top line.
		let contentHeight = bounds.height - Self.topLineThickness

		gearButton.frame = NSRect(x: Self.leadingMargin, y: 0, width: gearButton.intrinsicContentSize.width, height: contentHeight)

		var leftContentMaxX = gearButton.frame.maxX
		var x = leftContentMaxX + Self.spacingAfterGear
		if !progressIndicator.isHidden {
			leftContentMaxX = place(progressIndicator, x: x, width: Self.progressIndicatorWidth, contentHeight: contentHeight).maxX
			x = leftContentMaxX + Self.progressSpacing
		}

		// The count shows only with the sidebar. It fills the space up to the grip, so all of it is clickable.
		if let sidebarDividerPosition {
			let countMaxX = sidebarDividerPosition - Self.countClickAreaTrailingInset
			place(countLabel, x: x, width: countMaxX - x, contentHeight: contentHeight)
		}

		let leftSectionMaxX = sidebarDividerPosition ?? leftContentMaxX + Self.leftSectionTrailingInsetWithoutSidebar
		splitHandleView.frame = NSRect(x: leftSectionMaxX - Self.dragAreaReachBeforeDivider, y: 0, width: Self.dragAreaReachBeforeDivider + Self.dragAreaReachAfterDivider, height: contentHeight)

		var linkMaxX = bounds.maxX - Self.trailingMargin
		if !themePopUpButton.isHidden {
			let themeWidth = themePopUpButton.intrinsicContentSize.width
			linkMaxX = place(themePopUpButton, x: bounds.maxX - Self.trailingMargin - themeWidth, width: themeWidth, contentHeight: contentHeight).minX - Self.spacingBeforeThemeMenu
		}

		let linkX = leftSectionMaxX + Self.spacingAfterDivider
		place(linkLabel, x: linkX, width: linkMaxX - linkX, contentHeight: contentHeight)
	}

	override func draw(_ dirtyRect: NSRect) {
		// Draw within bounds only: views don’t clip to bounds by default, and dirtyRect can extend past them.
		if let gradient = Self.gradient {
			gradient.draw(in: bounds, angle: Self.gradientAngle)
		}

		Self.topLineColor.setFill()
		NSRect(x: bounds.minX, y: bounds.maxY - Self.topLineThickness, width: bounds.width, height: Self.topLineThickness).fill()

		// The sidebar divider continues through the bar as a hairline, with the ||| grip just before it.
		guard let sidebarDividerPosition else {
			return
		}
		Self.dividerColor.setFill()
		let hairline = 1 / (window?.backingScaleFactor ?? 1)
		let dividerX = sidebarDividerPosition + sidebarDividerLineOffset
		let contentHeight = bounds.height - Self.topLineThickness
		NSRect(x: dividerX, y: bounds.minY, width: sidebarDividerLineWidth, height: contentHeight).fill()

		Self.gripColor.setFill()
		let gripY = floor((contentHeight - Self.gripLineHeight) / 2)
		for index in 0..<Self.gripLineCount {
			let distanceFromLastLine = CGFloat(Self.gripLineCount - 1 - index) * Self.gripLineInterval
			let x = dividerX - Self.gripTrailingInset - distanceFromLastLine
			NSRect(x: x, y: gripY, width: hairline, height: Self.gripLineHeight).fill()
		}
	}

	override func viewDidChangeEffectiveAppearance() {
		super.viewDidChangeEffectiveAppearance()
		updateThemePopUpButtonShadow()
	}

	// MARK: - Notifications

	@objc func handleUnreadCountDidChange(_ notification: Notification) {
		CoalescingQueue.standard.add(self, #selector(updateCountLabel))
	}

	@objc func handleUnreadCountDisplaySettingDidChange(_ notification: Notification) {
		updateCountLabel()
	}

	@objc func handleAccountChildrenDidChange(_ notification: Notification) {
		CoalescingQueue.standard.add(self, #selector(updateCountLabel))
	}

	@objc func handleProgressInfoDidChange(_ notification: Notification) {
		CoalescingQueue.standard.add(self, #selector(updateCountLabel))
	}

	// The last refresh time shows the date only when it’s not today, so it changes at midnight.
	// These system notifications aren’t guaranteed to arrive on the main thread.
	@objc nonisolated func handleCalendarDayChanged(_ notification: Notification) {
		Task { @MainActor in
			self.updateCountLabel()
		}
	}

	@objc nonisolated func handleCurrentLocaleDidChange(_ notification: Notification) {
		Task { @MainActor in
			self.updateCountLabel()
		}
	}

	@objc nonisolated func handleSystemTimeZoneDidChange(_ notification: Notification) {
		Task { @MainActor in
			self.updateCountLabel()
		}
	}

	@objc func handleArticleThemeNamesDidChange(_ notification: Notification) {
		updateThemePopUpButton()
	}

	@objc func handleCurrentArticleThemeDidChange(_ notification: Notification) {
		updateThemePopUpButton()
	}

	@objc nonisolated func handleUserDefaultsDidChange(_ notification: Notification) {
		Task { @MainActor in
			CoalescingQueue.standard.add(self, #selector(self.updateCountLabel))
			self.updateThemePopUpButtonVisibility()
		}
	}

	// MARK: - Actions

	@objc func copyLink(_ sender: Any?) {
		guard let link, !link.isEmpty else {
			return
		}
		URLPasteboardWriter.write(urlStrings: [link], to: .general)
	}

	/// While refreshing, the label shows progress, and a click opens the Current Activity window. Otherwise a click toggles the count mode.
	@objc func countLabelClicked(_ sender: Any?) {
		if CombinedRefreshProgress.shared.progressInfo.isComplete {
			AppDefaults.statusBarCountMode = effectiveCountMode.next(includingUnreadCount: Self.showsUnreadCounts)
		} else {
			showActivityWindow(sender)
		}
	}

	@objc func showActivityWindow(_ sender: Any?) {
		NSApp.sendAction(#selector(AppDelegate.showActivityWindow(_:)), to: nil, from: self)
	}
}

// MARK: - NSMenuItemValidation

extension MainWindowStatusBarView: NSMenuItemValidation {

	func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
		guard menuItem.action == #selector(copyLink(_:)) else {
			return true
		}
		guard let link else {
			return false
		}
		return !link.isEmpty
	}
}

// MARK: - StatusBarGearButtonDelegate

extension MainWindowStatusBarView: StatusBarGearButtonDelegate {

	func gearButtonMenu(_ gearButton: StatusBarGearButton) -> NSMenu? {
		delegate?.statusBarViewGearMenu(self)
	}
}

// MARK: - StatusBarSplitHandleViewDelegate

extension MainWindowStatusBarView: StatusBarSplitHandleViewDelegate {

	func splitHandleViewDidBeginDragging(_ splitHandleView: StatusBarSplitHandleView) {
		dragStartDividerPosition = sidebarDividerPosition
	}

	func splitHandleView(_ splitHandleView: StatusBarSplitHandleView, didDragBy distance: CGFloat) {
		guard let dragStartDividerPosition else {
			return
		}
		delegate?.statusBarView(self, moveSidebarDividerTo: dragStartDividerPosition + distance)
	}
}

// MARK: - Private

private extension MainWindowStatusBarView {

	func commonInit() {
		heightAnchor.constraint(equalToConstant: Self.height).isActive = true

		// A labeled group, so VoiceOver can find the bar and move through its controls.
		setAccessibilityElement(true)
		setAccessibilityRole(.group)
		setAccessibilityLabel(NSLocalizedString("Status Bar", comment: "Main window status bar accessibility label"))

		gearButton.delegate = self

		progressIndicator.style = .bar
		progressIndicator.controlSize = .small
		progressIndicator.isIndeterminate = false
		progressIndicator.isHidden = true
		countLabel.isHidden = true

		progressIndicator.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(showActivityWindow(_:))))
		countLabel.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(countLabelClicked(_:))))

		linkLabel.menu = makeLinkMenu()

		splitHandleView.delegate = self
		splitHandleView.isHidden = true

		themePopUpButton.isBordered = false
		themePopUpButton.controlSize = .small
		themePopUpButton.font = NSFont.systemFont(ofSize: Self.fontSize)
		let themeDescription = NSLocalizedString("Article Theme", comment: "Article Theme")
		themePopUpButton.setAccessibilityLabel(themeDescription)
		themePopUpButton.toolTip = themeDescription
		updateThemePopUpButtonShadow()

		// The split handle is added last so it’s on top: it straddles the left section’s edge.
		for view in [gearButton, progressIndicator, countLabel, linkLabel, themePopUpButton, splitHandleView] {
			addSubview(view)
		}

		addObservers()

		updateCountLabel()
		updateLinkLabel()
		updateThemePopUpButton()
	}

	func addObservers() {
		NotificationCenter.default.addObserver(self, selector: #selector(handleUnreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleUnreadCountDidChange(_:)), name: .UnreadCountDidInitialize, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleUnreadCountDisplaySettingDidChange(_:)), name: .unreadCountDisplaySettingDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleAccountChildrenDidChange(_:)), name: .ChildrenDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleAccountChildrenDidChange(_:)), name: .BatchUpdateDidPerform, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleAccountChildrenDidChange(_:)), name: .UserDidAddAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleAccountChildrenDidChange(_:)), name: .UserDidDeleteAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleAccountChildrenDidChange(_:)), name: .AccountStateDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleProgressInfoDidChange(_:)), name: .progressInfoDidChange, object: CombinedRefreshProgress.shared)
		NotificationCenter.default.addObserver(self, selector: #selector(handleCalendarDayChanged(_:)), name: .NSCalendarDayChanged, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleCurrentLocaleDidChange(_:)), name: NSLocale.currentLocaleDidChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleSystemTimeZoneDidChange(_:)), name: .NSSystemTimeZoneDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleArticleThemeNamesDidChange(_:)), name: .ArticleThemeNamesDidChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleCurrentArticleThemeDidChange(_:)), name: .CurrentArticleThemeDidChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleUserDefaultsDidChange(_:)), name: UserDefaults.didChangeNotification, object: nil)
	}

	static func isDark(_ appearance: NSAppearance) -> Bool {
		appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
	}

	static func dynamicColor(lightWhite: CGFloat, darkWhite: CGFloat) -> NSColor {
		NSColor(name: nil) { appearance in
			let white = isDark(appearance) ? darkWhite : lightWhite
			return NSColor(srgbRed: white, green: white, blue: white, alpha: 1)
		}
	}

	/// Etched text, as in the count and the link.
	static func etchedString(_ string: String, font: NSFont, lineBreakMode: NSLineBreakMode) -> NSAttributedString {
		let paragraphStyle = NSMutableParagraphStyle()
		paragraphStyle.lineBreakMode = lineBreakMode
		let attributes: [NSAttributedString.Key: Any] = [
			.font: font,
			.foregroundColor: textColor,
			.shadow: etchedShadow,
			.paragraphStyle: paragraphStyle
		]
		return NSAttributedString(string: string, attributes: attributes)
	}

	/// Positions a view by its alignment rect — as Auto Layout would, so text fields’ built-in insets aren’t counted —
	/// vertically centered in the content area and aligned to device pixels. Returns the alignment rect.
	@discardableResult
	func place(_ view: NSView, x: CGFloat, width: CGFloat, contentHeight: CGFloat) -> NSRect {
		let height = view.intrinsicContentSize.height
		let alignmentRect = NSRect(x: x, y: (contentHeight - height) / 2, width: max(width, 0), height: height)
		view.frame = backingAlignedRect(view.frame(forAlignmentRect: alignmentRect), options: .alignAllEdgesNearest)
		return alignmentRect
	}

	// MARK: - Count

	@objc func updateCountLabel() {
		let progressInfo = CombinedRefreshProgress.shared.progressInfo
		progressIndicator.isHidden = progressInfo.isComplete

		if progressInfo.isComplete {
			setCountText(countText())
		} else {
			progressIndicator.maxValue = Double(progressInfo.numberOfTasks)
			progressIndicator.doubleValue = Double(progressInfo.numberCompleted)
			let formatString = NSLocalizedString("%@ of %@", comment: "Status bar progress")
			setCountText(String(format: formatString, NSNumber(value: progressInfo.numberCompleted), NSNumber(value: progressInfo.numberOfTasks)))
		}
		needsLayout = true
	}

	func setCountText(_ text: String) {
		let font = NSFont.monospacedDigitSystemFont(ofSize: Self.fontSize, weight: .regular)
		countLabel.attributedStringValue = Self.etchedString(text, font: font, lineBreakMode: .byTruncatingTail)
	}

	static var showsUnreadCounts: Bool {
		AppDefaults.unreadCountDisplay == .count
	}

	/// The saved mode, except that the unread count becomes the last refresh time when unread counts are hidden (hidden or a dot).
	var effectiveCountMode: StatusBarCountMode {
		let mode = AppDefaults.statusBarCountMode
		if mode == .unreadCount && !Self.showsUnreadCounts {
			return .lastRefresh
		}
		return mode
	}

	func countText() -> String {
		switch effectiveCountMode {
		case .lastRefresh:
			guard let lastRefreshDate = AccountManager.shared.lastRefreshCompletedDate else {
				return NSLocalizedString("Not updated yet", comment: "Status bar: no refresh has completed yet")
			}
			let formatString = NSLocalizedString("Updated %@", comment: "Updated")
			return String(format: formatString, Self.lastRefreshDateString(lastRefreshDate))

		case .unreadCount:
			let formatString = NSLocalizedString("%d unread", comment: "Unread")
			return String.localizedStringWithFormat(formatString, AccountManager.shared.unreadCount)

		case .foldersAndFeeds:
			let accounts = AccountManager.shared.activeAccounts
			let folderCount = accounts.reduce(0) { $0 + ($1.folders?.count ?? 0) }
			let feedCount = accounts.reduce(0) { $0 + $1.flattenedFeeds().count }
			let attributedString = AttributedString(localized: "^[\(folderCount) folder](inflect: true), ^[\(feedCount) feed](inflect: true)", comment: "Status bar: number of folders and feeds")
			return String(attributedString.characters)
		}
	}

	/// Just the time when it’s today, otherwise the date and time — in the user’s locale.
	static func lastRefreshDateString(_ date: Date) -> String {
		if Calendar.current.isDateInToday(date) {
			return date.formatted(date: .omitted, time: .shortened)
		}
		return date.formatted(date: .numeric, time: .shortened)
	}

	// MARK: - Link

	/// The link’s contextual menu. Copy copies the whole link, with its scheme.
	func makeLinkMenu() -> NSMenu {
		let menu = NSMenu()
		let copyItem = NSMenuItem(title: NSLocalizedString("Copy", comment: "Command"), action: #selector(copyLink(_:)), keyEquivalent: "")
		copyItem.target = self
		menu.addItem(copyItem)
		return menu
	}

	func updateLinkLabel() {
		guard let link, !link.isEmpty else {
			linkLabel.stringValue = ""
			linkLabel.toolTip = nil
			return
		}
		let font = NSFont.systemFont(ofSize: Self.fontSize)
		linkLabel.attributedStringValue = Self.etchedString(link.strippingHTTPOrHTTPSScheme, font: font, lineBreakMode: .byTruncatingMiddle)
		linkLabel.toolTip = link
	}

	// MARK: - Theme

	func updateThemePopUpButton() {
		themePopUpButton.menu = ArticleThemesManager.shared.makeArticleThemeMenu()
		themePopUpButton.selectItem(withTitle: ArticleThemesManager.shared.currentThemeName)
		updateThemePopUpButtonVisibility()
	}

	/// Etches the pop-up button’s title and arrows. A view’s shadow doesn’t follow appearance changes, so it’s resolved here.
	func updateThemePopUpButtonShadow() {
		let shadow = NSShadow()
		// A view’s shadow offset is in its own coordinates, and the pop-up button is flipped.
		let offset = Self.etchedShadow.shadowOffset
		shadow.shadowOffset = NSSize(width: offset.width, height: themePopUpButton.isFlipped ? -offset.height : offset.height)
		shadow.shadowBlurRadius = Self.etchedShadow.shadowBlurRadius
		effectiveAppearance.performAsCurrentDrawingAppearance {
			if let cgColor = Self.etchedShadow.shadowColor?.cgColor {
				shadow.shadowColor = NSColor(cgColor: cgColor)
			}
		}
		themePopUpButton.shadow = shadow
	}

	func updateThemePopUpButtonVisibility() {
		let isHidden = !AppDefaults.showStatusBarThemeMenu
		guard themePopUpButton.isHidden != isHidden else {
			return
		}
		themePopUpButton.isHidden = isHidden
		needsLayout = true
	}
}
