//
//  GeneralSettingsViewController.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 11/14/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import UIKit

final class GeneralSettingsViewController: UITableViewController {

	private enum Row: Int, CaseIterable {
		case colorPalette
		case unreadCounts
		case grayscaleIcons
	}

	private let colorPaletteCell = VibrantTableViewCell(style: .default, reuseIdentifier: nil)
	private let unreadCountDisplayCell = VibrantTableViewCell(style: .default, reuseIdentifier: nil)
	private let grayscaleIconsCell = VibrantTableViewCell(style: .default, reuseIdentifier: nil)

	private lazy var colorPalettePopUpButton = Self.makePopUpButton()
	private lazy var unreadCountDisplayPopUpButton = Self.makePopUpButton()
	private let grayscaleIconsSwitch = UISwitch()

	init() {
		super.init(style: .insetGrouped)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = NSLocalizedString("General", comment: "Preferences")

		NotificationCenter.default.addObserver(self, selector: #selector(handleUserInterfaceColorPaletteDidUpdate(_:)), name: .userInterfaceColorPaletteDidUpdate, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleUnreadCountDisplaySettingDidChange(_:)), name: .unreadCountDisplaySettingDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleGrayscaleIconsDidChange(_:)), name: .grayscaleIconsDidChange, object: nil)

		configureLabeledCell(colorPaletteCell, title: NSLocalizedString("Color Palette", comment: "Color Palette"))
		configureLabeledCell(unreadCountDisplayCell, title: NSLocalizedString("Unread Counts", comment: "Unread Counts"))
		configureLabeledCell(grayscaleIconsCell, title: NSLocalizedString("Grayscale Feed Icons", comment: "Grayscale Feed Icons"))

		addPopUpButton(colorPalettePopUpButton, to: colorPaletteCell, accessibilityLabel: NSLocalizedString("Color Palette", comment: "Color Palette"))
		addPopUpButton(unreadCountDisplayPopUpButton, to: unreadCountDisplayCell, accessibilityLabel: NSLocalizedString("Unread Counts", comment: "Unread Counts"))

		grayscaleIconsSwitch.onTintColor = Assets.Colors.primaryAccent
		grayscaleIconsSwitch.addTarget(self, action: #selector(switchGrayscaleIcons(_:)), for: .valueChanged)
		grayscaleIconsCell.accessoryView = grayscaleIconsSwitch

		updateColorPalettePopUpButton()
		updateUnreadCountDisplayPopUpButton()
		updateGrayscaleIconsSwitch()
	}

	// MARK: - UITableViewDataSource

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return Row.allCases.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		switch Row.allCases[indexPath.row] {
		case .colorPalette:
			return colorPaletteCell
		case .unreadCounts:
			return unreadCountDisplayCell
		case .grayscaleIcons:
			return grayscaleIconsCell
		}
	}

	// MARK: - Actions

	@objc func switchGrayscaleIcons(_ sender: UISwitch) {
		AppDefaults.grayscaleIcons = sender.isOn
	}

	// MARK: - Notifications

	@objc func handleUserInterfaceColorPaletteDidUpdate(_ notification: Notification) {
		updateColorPalettePopUpButton()
	}

	@objc func handleUnreadCountDisplaySettingDidChange(_ notification: Notification) {
		updateUnreadCountDisplayPopUpButton()
	}

	@objc func handleGrayscaleIconsDidChange(_ notification: Notification) {
		updateGrayscaleIconsSwitch()
	}
}

// MARK: - Private

private extension GeneralSettingsViewController {

	static func makePopUpButton() -> UIButton {
		var configuration = UIButton.Configuration.plain()
		configuration.baseForegroundColor = .secondaryLabel
		let button = UIButton(configuration: configuration)
		button.showsMenuAsPrimaryAction = true
		button.changesSelectionAsPrimaryAction = true
		return button
	}

	func configureLabeledCell(_ cell: UITableViewCell, title: String) {
		cell.selectionStyle = .none
		cell.textLabel?.text = title
		cell.textLabel?.numberOfLines = 0
		cell.textLabel?.adjustsFontForContentSizeCategory = true
	}

	/// Auto Layout lets the button resize itself when choosing an item changes its title.
	/// The accessibility label names the setting, since the button’s title is only the current choice.
	func addPopUpButton(_ button: UIButton, to cell: UITableViewCell, accessibilityLabel: String) {
		button.accessibilityLabel = accessibilityLabel
		button.translatesAutoresizingMaskIntoConstraints = false
		button.setContentCompressionResistancePriority(.required, for: .horizontal)
		cell.contentView.addSubview(button)
		NSLayoutConstraint.activate([
			button.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
			button.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
		])
	}

	func updateColorPalettePopUpButton() {
		let currentColorPalette = AppDefaults.userInterfaceColorPalette
		let actions = UserInterfaceColorPalette.allCases.map { colorPalette in
			UIAction(title: String(describing: colorPalette), state: colorPalette == currentColorPalette ? .on : .off) { _ in
				AppDefaults.userInterfaceColorPalette = colorPalette
			}
		}
		colorPalettePopUpButton.menu = UIMenu(children: actions)
		colorPalettePopUpButton.accessibilityValue = String(describing: currentColorPalette)
	}

	func updateUnreadCountDisplayPopUpButton() {
		let currentUnreadCountDisplay = AppDefaults.unreadCountDisplay
		let actions = UnreadCountDisplay.allCases.map { unreadCountDisplay in
			UIAction(title: String(describing: unreadCountDisplay), state: unreadCountDisplay == currentUnreadCountDisplay ? .on : .off) { _ in
				AppDefaults.unreadCountDisplay = unreadCountDisplay
			}
		}
		unreadCountDisplayPopUpButton.menu = UIMenu(children: actions)
		unreadCountDisplayPopUpButton.accessibilityValue = String(describing: currentUnreadCountDisplay)
	}

	func updateGrayscaleIconsSwitch() {
		grayscaleIconsSwitch.isOn = AppDefaults.grayscaleIcons
	}
}
