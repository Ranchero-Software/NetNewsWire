//
//  ArticlesSettingsViewController.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 11/17/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import UIKit

final class ArticlesSettingsViewController: UITableViewController {

	private enum Row: Int, CaseIterable {
		case theme
		case openLinksInNetNewsWire
		case enableJavaScript
		case swipeToNextPreviousArticle
		case enableFullScreenArticles
	}

	private let openLinksInNetNewsWireSwitch = UISwitch()
	private let enableJavaScriptSwitch = UISwitch()
	private let swipeToNextPreviousArticleSwitch = UISwitch()
	private let enableFullScreenArticlesSwitch = UISwitch()

	private let themeCell = VibrantTableViewCell(style: .value1, reuseIdentifier: nil)

	private var rows = [Row]()
	private var cells = [Row: UITableViewCell]()

	init() {
		super.init(style: .insetGrouped)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = NSLocalizedString("Articles", comment: "Articles")

		// The Full Screen Articles row is iPhone-only.
		rows = Row.allCases.filter { $0 != .enableFullScreenArticles || traitCollection.userInterfaceIdiom == .phone }

		themeCell.textLabel?.text = NSLocalizedString("Theme", comment: "Theme")
		themeCell.textLabel?.adjustsFontForContentSizeCategory = true
		themeCell.detailTextLabel?.adjustsFontForContentSizeCategory = true
		themeCell.accessoryType = .disclosureIndicator

		cells[.theme] = themeCell
		cells[.openLinksInNetNewsWire] = makeCell(switch: openLinksInNetNewsWireSwitch,
												  title: NSLocalizedString("Open Links in NetNewsWire", comment: "Open Links in NetNewsWire"),
												  footnote: nil,
												  action: #selector(switchOpenLinksInNetNewsWire(_:)))
		cells[.enableJavaScript] = makeCell(switch: enableJavaScriptSwitch,
											title: NSLocalizedString("Enable JavaScript", comment: "Enable JavaScript"),
											footnote: NSLocalizedString("Some content, such as videos and embedded social media posts, may require JavaScript to work correctly.", comment: "Some content, such as videos and embedded social media posts, may require JavaScript to work correctly."),
											action: #selector(switchEnableJavaScript(_:)))
		cells[.swipeToNextPreviousArticle] = makeCell(switch: swipeToNextPreviousArticleSwitch,
													  title: NSLocalizedString("Enable Horizontal Swipe to Previous and Next Article", comment: "Enable Horizontal Swipe to Previous and Next Article"),
													  footnote: nil,
													  action: #selector(switchSwipeToNextPreviousArticle(_:)))
		cells[.enableFullScreenArticles] = makeCell(switch: enableFullScreenArticlesSwitch,
													title: NSLocalizedString("Enable Full Screen Articles", comment: "Enable Full Screen Articles"),
													footnote: NSLocalizedString("Tap the article top bar to enter Full Screen. Tap the top or bottom to exit.", comment: "Tap the article top bar to enter Full Screen. Tap the top or bottom to exit."),
													action: #selector(switchEnableFullScreenArticles(_:)))
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		themeCell.detailTextLabel?.text = ArticleThemesManager.shared.currentTheme.name
		openLinksInNetNewsWireSwitch.isOn = !AppDefaults.useSystemBrowser
		enableJavaScriptSwitch.isOn = AppDefaults.isArticleContentJavascriptEnabled
		swipeToNextPreviousArticleSwitch.isOn = AppDefaults.articleSwipeNavigationEnabled
		enableFullScreenArticlesSwitch.isOn = AppDefaults.articleFullscreenAvailable
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
	}

	// MARK: - UITableViewDataSource

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return rows.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		return cells[rows[indexPath.row]] ?? UITableViewCell()
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		switch rows[indexPath.row] {
		case .theme:
			let articleThemes = UIStoryboard.settings.instantiateController(ofType: ArticleThemesTableViewController.self)
			navigationController?.pushViewController(articleThemes, animated: true)
		default:
			tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
		}
	}

	// MARK: - Actions

	@objc func switchOpenLinksInNetNewsWire(_ sender: UISwitch) {
		AppDefaults.useSystemBrowser = !sender.isOn
	}

	@objc func switchEnableJavaScript(_ sender: UISwitch) {
		AppDefaults.isArticleContentJavascriptEnabled = sender.isOn
	}

	@objc func switchSwipeToNextPreviousArticle(_ sender: UISwitch) {
		AppDefaults.articleSwipeNavigationEnabled = sender.isOn
	}

	@objc func switchEnableFullScreenArticles(_ sender: UISwitch) {
		AppDefaults.articleFullscreenAvailable = sender.isOn
	}
}

// MARK: - Private

private extension ArticlesSettingsViewController {

	/// A plain cell, rather than a vibrant one, so the footnote keeps its secondary color.
	func makeCell(switch toggle: UISwitch, title: String, footnote: String?, action: Selector) -> UITableViewCell {
		let cell = UITableViewCell(style: footnote == nil ? .default : .subtitle, reuseIdentifier: nil)
		cell.selectionStyle = .none
		cell.textLabel?.text = title
		cell.textLabel?.numberOfLines = 0
		cell.textLabel?.adjustsFontForContentSizeCategory = true
		if let footnote {
			cell.detailTextLabel?.text = footnote
			cell.detailTextLabel?.numberOfLines = 0
			cell.detailTextLabel?.font = .preferredFont(forTextStyle: .footnote)
			cell.detailTextLabel?.textColor = .secondaryLabel
			cell.detailTextLabel?.adjustsFontForContentSizeCategory = true
		}
		toggle.onTintColor = Assets.Colors.primaryAccent
		toggle.addTarget(self, action: action, for: .valueChanged)
		cell.accessoryView = toggle
		return cell
	}
}
