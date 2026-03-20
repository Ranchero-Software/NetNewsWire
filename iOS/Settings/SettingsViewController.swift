//
//  SettingsViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/24/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import CoreServices
import SafariServices
import SwiftUI
import UniformTypeIdentifiers
import RSCore
import Account

final class SettingsViewController: UITableViewController {

	private enum Section: Int {
		case notifications = 0
		case accounts = 1
		case feeds = 2
		case timeline = 3
		case articles = 4
		case appearance = 5
		case troubleshooting = 6
		case help = 7
	}

	private weak var opmlAccount: Account?
	private let aiSummarySettingsCellReuseIdentifier = "AISummarySettingsCell"

	@IBOutlet var timelineSortOrderSwitch: UISwitch!
	@IBOutlet var groupByFeedSwitch: UISwitch!
	@IBOutlet var refreshClearsReadArticlesSwitch: UISwitch!
	@IBOutlet var articleThemeDetailLabel: UILabel!
	@IBOutlet var confirmMarkAllAsReadSwitch: UISwitch!
	@IBOutlet var showFullscreenArticlesSwitch: UISwitch!
	@IBOutlet var colorPaletteDetailLabel: UILabel!
	@IBOutlet var openLinksInNetNewsWire: UISwitch!
	@IBOutlet var enableJavaScriptSwitch: UISwitch!

	var scrollToArticlesSection = false
	weak var presentingParentController: UIViewController?

	override func viewDidLoad() {
		// This hack mostly works around a bug in static tables with dynamic type.  See: https://spin.atomicobject.com/2018/10/15/dynamic-type-static-uitableview/
		NotificationCenter.default.removeObserver(tableView!, name: UIContentSizeCategory.didChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(contentSizeCategoryDidChange), name: UIContentSizeCategory.didChangeNotification, object: nil)

		NotificationCenter.default.addObserver(self, selector: #selector(accountsDidChange), name: .UserDidAddAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountsDidChange), name: .UserDidDeleteAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(displayNameDidChange), name: .DisplayNameDidChange, object: nil)

		tableView.register(UINib(nibName: "SettingsComboTableViewCell", bundle: nil), forCellReuseIdentifier: "SettingsComboTableViewCell")
		tableView.register(UINib(nibName: "SettingsTableViewCell", bundle: nil), forCellReuseIdentifier: "SettingsTableViewCell")

		tableView.rowHeight = UITableView.automaticDimension
		tableView.estimatedRowHeight = 44
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		if AppDefaults.shared.timelineSortDirection == .orderedAscending {
			timelineSortOrderSwitch.isOn = true
		} else {
			timelineSortOrderSwitch.isOn = false
		}

		if AppDefaults.shared.timelineGroupByFeed {
			groupByFeedSwitch.isOn = true
		} else {
			groupByFeedSwitch.isOn = false
		}

		if AppDefaults.shared.refreshClearsReadArticles {
			refreshClearsReadArticlesSwitch.isOn = true
		} else {
			refreshClearsReadArticlesSwitch.isOn = false
		}

		articleThemeDetailLabel.text = ArticleThemesManager.shared.currentTheme.name

		if AppDefaults.shared.confirmMarkAllAsRead {
			confirmMarkAllAsReadSwitch.isOn = true
		} else {
			confirmMarkAllAsReadSwitch.isOn = false
		}

		if AppDefaults.shared.articleFullscreenAvailable {
			showFullscreenArticlesSwitch.isOn = true
		} else {
			showFullscreenArticlesSwitch.isOn = false
		}

		if AppDefaults.shared.isArticleContentJavascriptEnabled {
			enableJavaScriptSwitch.isOn = true
		} else {
			enableJavaScriptSwitch.isOn = false
		}

		colorPaletteDetailLabel.text = String(describing: AppDefaults.userInterfaceColorPalette)

		openLinksInNetNewsWire.isOn = !AppDefaults.shared.useSystemBrowser

		let buildLabel = NonIntrinsicLabel(frame: CGRect(x: 32.0, y: 0.0, width: 0.0, height: 0.0))
		buildLabel.font = UIFont.systemFont(ofSize: 11.0)
		buildLabel.textColor = UIColor.gray
		buildLabel.text = "\(Bundle.main.appName) \(Bundle.main.versionNumber) (Build \(Bundle.main.buildNumber))"
		buildLabel.sizeToFit()
		buildLabel.translatesAutoresizingMaskIntoConstraints = false

		let wrapperView = UIView(frame: CGRect(x: 0, y: 0, width: buildLabel.frame.width, height: buildLabel.frame.height + 10.0))
		wrapperView.translatesAutoresizingMaskIntoConstraints = false
		wrapperView.addSubview(buildLabel)
		tableView.tableFooterView = wrapperView
		tableView.reloadData()

	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		self.tableView.selectRow(at: nil, animated: true, scrollPosition: .none)

		if scrollToArticlesSection {
			tableView.scrollToRow(at: IndexPath(row: 0, section: Section.articles.rawValue), at: .top, animated: true)
			scrollToArticlesSection = false
		}

	}

	// MARK: UITableView

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

		switch Section(rawValue: section) {
		case .accounts:
			return AccountManager.shared.accounts.count + 1
		case .feeds:
			let defaultNumberOfRows = super.tableView(tableView, numberOfRowsInSection: section)
			if AccountManager.shared.activeAccounts.isEmpty || AccountManager.shared.anyAccountHasNetNewsWireNewsSubscription() {
				return defaultNumberOfRows - 1
			}
			return defaultNumberOfRows
		case .articles:
			return traitCollection.userInterfaceIdiom == .phone ? 6 : 5
		default:
			return super.tableView(tableView, numberOfRowsInSection: section)
		}
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

		let cell: UITableViewCell
		switch Section(rawValue: indexPath.section) {
		case .accounts:

			let sortedAccounts = AccountManager.shared.sortedAccounts
			if indexPath.row == sortedAccounts.count {
				cell = tableView.dequeueReusableCell(withIdentifier: "SettingsTableViewCell", for: indexPath)
				cell.textLabel?.text = NSLocalizedString("Add Account", comment: "Accounts")
			} else {
				let acctCell = tableView.dequeueReusableCell(withIdentifier: "SettingsComboTableViewCell", for: indexPath) as! SettingsComboTableViewCell
				acctCell.applyThemeProperties()
				let account = sortedAccounts[indexPath.row]
				acctCell.comboImage?.image = Assets.accountImage(account.type)
				acctCell.comboNameLabel?.text = account.nameForDisplay
				cell = acctCell
			}
		case .articles where indexPath.row == aiSummarySettingsRowIndex:
			let aiSummaryCell = tableView.dequeueReusableCell(withIdentifier: aiSummarySettingsCellReuseIdentifier) ??
				UITableViewCell(style: .subtitle, reuseIdentifier: aiSummarySettingsCellReuseIdentifier)
			aiSummaryCell.textLabel?.text = NSLocalizedString("AI Summary", comment: "AI Summary")
			aiSummaryCell.detailTextLabel?.text = aiSummarySettingsSubtitle()
			aiSummaryCell.accessoryType = .disclosureIndicator
			aiSummaryCell.selectionStyle = .default
			aiSummaryCell.detailTextLabel?.textColor = .secondaryLabel
			cell = aiSummaryCell
		default:
			cell = super.tableView(tableView, cellForRowAt: indexPath)

		}

		return cell
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

		switch Section(rawValue: indexPath.section) {
		case .notifications:
			UIApplication.shared.open(URL(string: "\(UIApplication.openSettingsURLString)")!)
			tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
		case .accounts:
			let sortedAccounts = AccountManager.shared.sortedAccounts
			if indexPath.row == sortedAccounts.count {
				let controller = UIStoryboard.settings.instantiateController(ofType: AddAccountViewController.self)
				self.navigationController?.pushViewController(controller, animated: true)
			} else {
				let controller = UIStoryboard.inspector.instantiateController(ofType: AccountInspectorViewController.self)
				controller.account = sortedAccounts[indexPath.row]
				self.navigationController?.pushViewController(controller, animated: true)
			}
		case .feeds:
			switch indexPath.row {
			case 0:
				tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
				if let sourceView = tableView.cellForRow(at: indexPath) {
					let sourceRect = tableView.rectForRow(at: indexPath)
					importOPML(sourceView: sourceView, sourceRect: sourceRect)
				}
			case 1:
				tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
				if let sourceView = tableView.cellForRow(at: indexPath) {
					let sourceRect = tableView.rectForRow(at: indexPath)
					exportOPML(sourceView: sourceView, sourceRect: sourceRect)
				}
			case 2:
				addFeed()
				tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
			default:
				break
			}
		case .timeline:
			switch indexPath.row {
			case 3:
				let timeline = UIStoryboard.settings.instantiateController(ofType: TimelineCustomizerCollectionViewController.self)
				self.navigationController?.pushViewController(timeline, animated: true)
			default:
				break
			}
		case .articles:
			if indexPath.row == aiSummarySettingsRowIndex {
				tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
				presentAISummarySettingsEditor()
				return
			}

			switch indexPath.row {
			case 0:
				let articleThemes = UIStoryboard.settings.instantiateController(ofType: ArticleThemesTableViewController.self)
				self.navigationController?.pushViewController(articleThemes, animated: true)
			default:
				break
			}
		case .appearance:
			let colorPalette = UIStoryboard.settings.instantiateController(ofType: ColorPaletteTableViewController.self)
			self.navigationController?.pushViewController(colorPalette, animated: true)
		case .troubleshooting:
			let hosting = UIHostingController(rootView: ErrorLogView())
			self.navigationController?.pushViewController(hosting, animated: true)
		case .help:
			switch indexPath.row {
			case 0:
				openURL(HelpURL.helpHome.rawValue)
				tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
			case 1:
				openURL(HelpURL.discourse.rawValue)
				tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
			case 2:
				openURL(HelpURL.releaseNotes.rawValue)
				tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
			case 3:
				openURL(HelpURL.bugTracker.rawValue)
				tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
			case 4:
				let hosting = UIHostingController(rootView: AboutView())
				self.navigationController?.pushViewController(hosting, animated: true)
			default:
				break
			}
		default:
			tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
		}
	}

	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		return false
	}

	override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
		return false
	}

	override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
		return .none
	}

	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return UITableView.automaticDimension
	}

	override func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int {
		return super.tableView(tableView, indentationLevelForRowAt: IndexPath(row: 0, section: 1))
	}

	// MARK: Actions

	@IBAction func done(_ sender: Any) {
		dismiss(animated: true)
	}

	@IBAction func switchTimelineOrder(_ sender: Any) {
		if timelineSortOrderSwitch.isOn {
			AppDefaults.shared.timelineSortDirection = .orderedAscending
		} else {
			AppDefaults.shared.timelineSortDirection = .orderedDescending
		}
	}

	@IBAction func switchGroupByFeed(_ sender: Any) {
		if groupByFeedSwitch.isOn {
			AppDefaults.shared.timelineGroupByFeed = true
		} else {
			AppDefaults.shared.timelineGroupByFeed = false
		}
	}

	@IBAction func switchClearsReadArticles(_ sender: Any) {
		if refreshClearsReadArticlesSwitch.isOn {
			AppDefaults.shared.refreshClearsReadArticles = true
		} else {
			AppDefaults.shared.refreshClearsReadArticles = false
		}
	}

	@IBAction func switchConfirmMarkAllAsRead(_ sender: Any) {
		if confirmMarkAllAsReadSwitch.isOn {
			AppDefaults.shared.confirmMarkAllAsRead = true
		} else {
			AppDefaults.shared.confirmMarkAllAsRead = false
		}
	}

	@IBAction func switchFullscreenArticles(_ sender: Any) {
		if showFullscreenArticlesSwitch.isOn {
			AppDefaults.shared.articleFullscreenAvailable = true
		} else {
			AppDefaults.shared.articleFullscreenAvailable = false
		}
	}

	@IBAction func switchBrowserPreference(_ sender: Any) {
		if openLinksInNetNewsWire.isOn {
			AppDefaults.shared.useSystemBrowser = false
		} else {
			AppDefaults.shared.useSystemBrowser = true
		}
	}

	@IBAction func switchJavaScriptPreference(_ sender: Any) {
		AppDefaults.shared.isArticleContentJavascriptEnabled = enableJavaScriptSwitch.isOn
 	}

	// MARK: - Notifications

	@objc func contentSizeCategoryDidChange() {
		tableView.reloadData()
	}

	@objc func accountsDidChange() {
		tableView.reloadData()
	}

	@objc func displayNameDidChange() {
		tableView.reloadData()
	}

	@objc func browserPreferenceDidChange() {
		tableView.reloadData()
	}

}

// MARK: - OPML Document Picker

extension SettingsViewController: UIDocumentPickerDelegate {

	func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
		for url in urls {
			opmlAccount?.importOPML(url) { result in
				switch result {
				case .success:
					break
				case .failure:
					let title = NSLocalizedString("Import Failed", comment: "Import Failed")
					let message = NSLocalizedString("We were unable to process the selected file.  Please ensure that it is a properly formatted OPML file.", comment: "Import Failed Message")
					self.presentError(title: title, message: message)
				}
			}
		}
	}

}

// MARK: - Private

private extension SettingsViewController {

	var aiSummarySettingsRowIndex: Int {
		traitCollection.userInterfaceIdiom == .phone ? 5 : 4
	}

	func aiSummarySettingsSubtitle() -> String {
		if AppDefaults.shared.isAISummaryConfigured {
			let format = NSLocalizedString("Configured: %@ (%@)", comment: "AI summary configured label with URL and model")
			return String(format: format, AppDefaults.shared.aiSummaryAPIURL, AppDefaults.shared.aiSummaryModel)
		}
		return NSLocalizedString("Tap to configure URL, API Key, and model", comment: "AI summary configuration hint")
	}

	func presentAISummarySettingsEditor() {
		let controller = AISummarySettingsViewController()
		navigationController?.pushViewController(controller, animated: true)
	}

	func addFeed() {
		self.dismiss(animated: true)

		let addNavViewController = UIStoryboard.add.instantiateViewController(withIdentifier: "AddFeedViewControllerNav") as! UINavigationController
		let addViewController = addNavViewController.topViewController as! AddFeedViewController
		addViewController.initialFeed = AccountManager.netNewsWireNewsURL
		addViewController.initialFeedName = NSLocalizedString("NetNewsWire News", comment: "NetNewsWire News")
		addNavViewController.modalPresentationStyle = .formSheet
		addNavViewController.preferredContentSize = AddFeedViewController.preferredContentSizeForFormSheetDisplay

		presentingParentController?.present(addNavViewController, animated: true)
	}

	func importOPML(sourceView: UIView, sourceRect: CGRect) {
		switch AccountManager.shared.activeAccounts.count {
		case 0:
			presentError(title: "Error", message: NSLocalizedString("You must have at least one active account.", comment: "Missing active account"))
		case 1:
			opmlAccount = AccountManager.shared.activeAccounts.first
			importOPMLDocumentPicker()
		default:
			importOPMLAccountPicker(sourceView: sourceView, sourceRect: sourceRect)
		}
	}

	func importOPMLAccountPicker(sourceView: UIView, sourceRect: CGRect) {
		let title = NSLocalizedString("Choose an account to receive the imported feeds and folders", comment: "Import Account")
		let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)

		if let popoverController = alert.popoverPresentationController {
			popoverController.sourceView = view
			popoverController.sourceRect = sourceRect
		}

		for account in AccountManager.shared.sortedActiveAccounts {
			let action = UIAlertAction(title: account.nameForDisplay, style: .default) { [weak self] _ in
				self?.opmlAccount = account
				self?.importOPMLDocumentPicker()
			}
			alert.addAction(action)
		}

		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
		alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel))

		self.present(alert, animated: true)
	}

	func importOPMLDocumentPicker() {
		var contentTypes: [UTType] = []

		// Create UTType for .opml files by extension, without requiring conformance.
		// This ensures files ending in .opml can be selected no matter how OPML is registered.
		// <https://github.com/Ranchero-Software/NetNewsWire/issues/4858>
		if let opmlByExtension = UTType(filenameExtension: "opml") {
			contentTypes.append(opmlByExtension)
		}

		// Also try the registered org.opml.opml UTI if it exists
		if let registeredOPML = UTType("org.opml.opml") {
			contentTypes.append(registeredOPML)
		}

		// Include XML as a fallback
		contentTypes.append(.xml)

		let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
		documentPicker.delegate = self
		documentPicker.modalPresentationStyle = .formSheet
		self.present(documentPicker, animated: true)
	}

	func exportOPML(sourceView: UIView, sourceRect: CGRect) {
		if AccountManager.shared.accounts.count == 1 {
			opmlAccount = AccountManager.shared.accounts.first!
			exportOPMLDocumentPicker()
		} else {
			exportOPMLAccountPicker(sourceView: sourceView, sourceRect: sourceRect)
		}
	}

	func exportOPMLAccountPicker(sourceView: UIView, sourceRect: CGRect) {
		let title = NSLocalizedString("Choose an account with the subscriptions to export", comment: "Export Account")
		let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)

		if let popoverController = alert.popoverPresentationController {
			popoverController.sourceView = view
			popoverController.sourceRect = sourceRect
		}

		for account in AccountManager.shared.sortedAccounts {
			let action = UIAlertAction(title: account.nameForDisplay, style: .default) { [weak self] _ in
				self?.opmlAccount = account
				self?.exportOPMLDocumentPicker()
			}
			alert.addAction(action)
		}

		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
		alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel))

		self.present(alert, animated: true)
	}

	func exportOPMLDocumentPicker() {
		guard let account = opmlAccount else { return }

		let accountName = account.nameForDisplay.replacingOccurrences(of: " ", with: "").trimmingCharacters(in: .whitespaces)
		let filename = "Subscriptions-\(accountName).opml"
		let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
		let opmlString = OPMLExporter.OPMLString(with: account, title: filename)
		do {
			try opmlString.write(to: tempFile, atomically: true, encoding: String.Encoding.utf8)
		} catch {
			self.presentError(title: "OPML Export Error", message: error.localizedDescription)
		}

		let docPicker = UIDocumentPickerViewController(forExporting: [tempFile])
		docPicker.modalPresentationStyle = .formSheet
		self.present(docPicker, animated: true)
	}

	func openURL(_ urlString: String) {
		let vc = SFSafariViewController(url: URL(string: urlString)!)
		vc.modalPresentationStyle = .pageSheet
		present(vc, animated: true)
	}
}

@MainActor
private final class AISummarySettingsViewController: UIViewController, UITextFieldDelegate {

	private let descriptionLabel = UILabel()
	private let urlLabel = UILabel()
	private let urlField = UITextField()
	private let apiKeyLabel = UILabel()
	private let apiKeyField = UITextField()
	private let modelLabel = UILabel()
	private let modelButton = UIButton(type: .system)
	private let saveButton = UIButton(type: .system)
	private let clearButton = UIButton(type: .system)
	private let statusLabel = UILabel()

	private var modelReloadWorkItem: DispatchWorkItem?
	private var modelLoadTask: Task<Void, Never>?
	private var lastLoadedSignature: String?
	private var latestRequestedSignature: String?
	private var availableModels = [String]()
	private var selectedModel: String?
	private var isSavingConfiguration = false

	override func viewDidLoad() {
		super.viewDidLoad()
		title = NSLocalizedString("AI Summary", comment: "AI Summary")
		buildUI()
		reloadValues()
	}
}

private extension AISummarySettingsViewController {

	func buildUI() {
		view.backgroundColor = .systemGroupedBackground

		descriptionLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
		descriptionLabel.textColor = .secondaryLabel
		descriptionLabel.numberOfLines = 0
		descriptionLabel.text = NSLocalizedString("Configure an OpenAI-compatible API URL and API Key.", comment: "AI summary settings message")

		urlLabel.font = UIFont.preferredFont(forTextStyle: .headline)
		urlLabel.text = NSLocalizedString("URL", comment: "URL")
		urlField.placeholder = AISummaryService.defaultAPIURLString
		urlField.borderStyle = .roundedRect
		urlField.autocapitalizationType = .none
		urlField.autocorrectionType = .no
		urlField.keyboardType = .URL
		urlField.returnKeyType = .next
		urlField.clearButtonMode = .whileEditing
		urlField.delegate = self
		urlField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)

		apiKeyLabel.font = UIFont.preferredFont(forTextStyle: .headline)
		apiKeyLabel.text = NSLocalizedString("API Key", comment: "API Key")
		apiKeyField.placeholder = "sk-..."
		apiKeyField.borderStyle = .roundedRect
		apiKeyField.autocapitalizationType = .none
		apiKeyField.autocorrectionType = .no
		apiKeyField.clearButtonMode = .whileEditing
		apiKeyField.isSecureTextEntry = true
		apiKeyField.returnKeyType = .done
		apiKeyField.delegate = self
		apiKeyField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)

		modelLabel.font = UIFont.preferredFont(forTextStyle: .headline)
		modelLabel.text = NSLocalizedString("Model", comment: "Model")
		modelButton.addTarget(self, action: #selector(selectModelTapped(_:)), for: .touchUpInside)
		var modelConfig = UIButton.Configuration.plain()
		modelConfig.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
		modelConfig.titleAlignment = .leading
		modelButton.configuration = modelConfig
		modelButton.layer.cornerRadius = 10
		modelButton.layer.borderWidth = 1
		modelButton.layer.borderColor = UIColor.separator.cgColor
		modelButton.backgroundColor = .secondarySystemGroupedBackground
		modelButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true

		var saveConfig = UIButton.Configuration.filled()
		saveConfig.title = NSLocalizedString("Save", comment: "Save")
		saveButton.configuration = saveConfig
		saveButton.addTarget(self, action: #selector(saveTapped(_:)), for: .touchUpInside)

		var clearConfig = UIButton.Configuration.bordered()
		clearConfig.title = NSLocalizedString("Clear", comment: "Clear")
		clearButton.configuration = clearConfig
		clearButton.addTarget(self, action: #selector(clearTapped(_:)), for: .touchUpInside)

		statusLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
		statusLabel.textColor = .secondaryLabel
		statusLabel.numberOfLines = 0

		let scrollView = UIScrollView()
		scrollView.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(scrollView)

		let contentView = UIView()
		contentView.translatesAutoresizingMaskIntoConstraints = false
		scrollView.addSubview(contentView)

		let urlStack = makeRow(label: urlLabel, content: urlField)
		let apiKeyStack = makeRow(label: apiKeyLabel, content: apiKeyField)
		let modelStack = makeRow(label: modelLabel, content: modelButton)

		let actionStack = UIStackView(arrangedSubviews: [saveButton, clearButton])
		actionStack.axis = .horizontal
		actionStack.spacing = 12
		actionStack.distribution = .fillEqually

		let stack = UIStackView(arrangedSubviews: [descriptionLabel, urlStack, apiKeyStack, modelStack, actionStack, statusLabel])
		stack.axis = .vertical
		stack.spacing = 14
		stack.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(stack)

		NSLayoutConstraint.activate([
			scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
			scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
			scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
			scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

			contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
			contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
			contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
			contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
			contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

			stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
			stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
			stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
			stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
		])
	}

	func makeRow(label: UILabel, content: UIView) -> UIStackView {
		let stack = UIStackView(arrangedSubviews: [label, content])
		stack.axis = .vertical
		stack.spacing = 8
		return stack
	}

	func reloadValues() {
		setSavingState(false)
		let storedURL = (UserDefaults.standard.string(forKey: AppDefaults.Key.aiSummaryAPIURL) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
		urlField.text = storedURL.isEmpty ? "" : (normalizedAPIURL(from: storedURL) ?? storedURL)
		apiKeyField.text = AppDefaults.shared.aiSummaryAPIKey
		selectedModel = AppDefaults.shared.aiSummaryModel
		setStatus(text: "", color: .secondaryLabel)
		lastLoadedSignature = nil
		reloadModelList(force: true, preferredModel: selectedModel)
	}

	@objc func textFieldDidChange(_ sender: UITextField) {
		setStatus(text: "", color: .secondaryLabel)
		scheduleModelListReload()
	}

	@objc func selectModelTapped(_ sender: UIButton) {
		guard !isSavingConfiguration, !availableModels.isEmpty else {
			return
		}

		let alert = UIAlertController(title: NSLocalizedString("Model", comment: "Model"), message: nil, preferredStyle: .actionSheet)
		for model in availableModels {
			alert.addAction(UIAlertAction(title: model, style: .default) { [weak self] _ in
				guard let self else { return }
				self.selectedModel = model
				self.updateModelButton(title: model, enabled: true)
			})
		}
		alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel))

		if let popover = alert.popoverPresentationController {
			popover.sourceView = sender
			popover.sourceRect = sender.bounds
		}

		present(alert, animated: true)
	}

	@objc func saveTapped(_ sender: UIButton) {
		guard !isSavingConfiguration else {
			return
		}

		let apiURLInput = (urlField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
		let apiKey = (apiKeyField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
		let model = selectedModelForSaving().trimmingCharacters(in: .whitespacesAndNewlines)

		guard let apiURL = effectiveAPIURL(from: apiURLInput) else {
			setStatus(text: NSLocalizedString("Invalid URL", comment: "Invalid URL"), color: .systemRed)
			return
		}

		guard !model.isEmpty else {
			setStatus(text: NSLocalizedString("Select a model", comment: "Select model before saving"), color: .systemRed)
			return
		}

		guard !apiKey.isEmpty else {
			setStatus(text: NSLocalizedString("API Key is required", comment: "AI Summary API key required"), color: .systemRed)
			return
		}

		setSavingState(true)
		setStatus(text: NSLocalizedString("Testing model...", comment: "Testing selected model before saving"), color: .secondaryLabel)

		Task { [weak self] in
			guard let self else {
				return
			}

			do {
				try await AISummaryService.shared.validateModelAvailability(urlString: apiURL, apiKey: apiKey, model: model)
				await MainActor.run {
					AppDefaults.shared.aiSummaryAPIURL = apiURLInput.isEmpty ? "" : apiURL
					AppDefaults.shared.aiSummaryAPIKey = apiKey
					AppDefaults.shared.aiSummaryModel = model
					self.urlField.text = apiURLInput.isEmpty ? "" : apiURL
					self.setSavingState(false)
					self.setStatus(text: NSLocalizedString("Saved", comment: "Saved"), color: .systemGreen)
				}
			} catch is CancellationError {
				await MainActor.run {
					self.setSavingState(false)
				}
			} catch {
				await MainActor.run {
					self.setSavingState(false)
					self.setStatus(text: error.localizedDescription, color: .systemRed)
				}
			}
		}
	}

	@objc func clearTapped(_ sender: UIButton) {
		AppDefaults.shared.aiSummaryAPIURL = ""
		AppDefaults.shared.aiSummaryAPIKey = ""
		AppDefaults.shared.aiSummaryModel = ""
		reloadValues()
		setStatus(text: NSLocalizedString("Cleared", comment: "Cleared"), color: .secondaryLabel)
	}

	func scheduleModelListReload() {
		modelReloadWorkItem?.cancel()

		let workItem = DispatchWorkItem { [weak self] in
			guard let self else { return }
			self.reloadModelList(force: false, preferredModel: self.currentPreferredModel())
		}
		modelReloadWorkItem = workItem
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: workItem)
	}

	func reloadModelList(force: Bool, preferredModel: String?) {
		guard let credentials = credentialsForModelLoading() else {
			lastLoadedSignature = nil
			latestRequestedSignature = nil
			showModelPlaceholder(NSLocalizedString("Enter URL and API Key", comment: "Model list placeholder when URL/key missing"))
			return
		}

		let signature = "\(credentials.url)\n\(credentials.apiKey)"
		if !force, signature == lastLoadedSignature {
			return
		}

		latestRequestedSignature = signature
		showModelPlaceholder(NSLocalizedString("Loading models...", comment: "Model loading"))
		modelLoadTask?.cancel()

		modelLoadTask = Task { [weak self] in
			guard let self else {
				return
			}

			do {
				let models = try await AISummaryService.shared.fetchAvailableModels(urlString: credentials.url, apiKey: credentials.apiKey)
				await MainActor.run {
					guard self.latestRequestedSignature == signature else {
						return
					}
					self.lastLoadedSignature = signature
					self.updateModelSelection(with: models, preferredModel: preferredModel)
				}
			} catch is CancellationError {
				return
			} catch {
				await MainActor.run {
					guard self.latestRequestedSignature == signature else {
						return
					}
					self.lastLoadedSignature = nil
					self.showModelPlaceholder(NSLocalizedString("Failed to load models", comment: "Model loading failed"))
				}
			}
		}
	}

	func credentialsForModelLoading() -> (url: String, apiKey: String)? {
		let urlInput = (urlField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
		let apiKey = (apiKeyField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

		guard !apiKey.isEmpty,
			  let normalizedURL = effectiveAPIURL(from: urlInput) else {
			return nil
		}

		return (normalizedURL, apiKey)
	}

	func showModelPlaceholder(_ title: String) {
		availableModels.removeAll()
		updateModelButton(title: title, enabled: false)
	}

	func updateModelSelection(with models: [String], preferredModel: String?) {
		availableModels = models

		guard !models.isEmpty else {
			showModelPlaceholder(NSLocalizedString("No models available", comment: "No models"))
			return
		}

		let preferred = (preferredModel ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
		if !preferred.isEmpty, models.contains(preferred) {
			selectedModel = preferred
		} else {
			let savedModel = AppDefaults.shared.aiSummaryModel.trimmingCharacters(in: .whitespacesAndNewlines)
			selectedModel = models.contains(savedModel) ? savedModel : models[0]
		}

		updateModelButton(title: selectedModel ?? models[0], enabled: true)
	}

	func updateModelButton(title: String, enabled: Bool) {
		let isEnabled = enabled && !isSavingConfiguration
		modelButton.isEnabled = isEnabled
		var config = modelButton.configuration ?? UIButton.Configuration.plain()
		config.title = title
		config.baseForegroundColor = isEnabled ? .label : .secondaryLabel
		modelButton.configuration = config
	}

	func setSavingState(_ isSaving: Bool) {
		isSavingConfiguration = isSaving
		urlField.isEnabled = !isSaving
		apiKeyField.isEnabled = !isSaving
		saveButton.isEnabled = !isSaving
		clearButton.isEnabled = !isSaving
		updateModelButton(title: modelButton.configuration?.title ?? "", enabled: !availableModels.isEmpty)
	}

	func currentPreferredModel() -> String {
		if let selectedModel, !selectedModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			return selectedModel
		}
		return AppDefaults.shared.aiSummaryModel
	}

	func selectedModelForSaving() -> String {
		guard let selectedModel, availableModels.contains(selectedModel) else {
			return AppDefaults.shared.aiSummaryModel
		}
		return selectedModel
	}

	func setStatus(text: String, color: UIColor) {
		statusLabel.text = text
		statusLabel.textColor = color
	}

	func normalizedAPIURL(from text: String) -> String? {
		AISummaryService.normalizedAPIURLString(from: text)
	}

	func effectiveAPIURL(from text: String) -> String? {
		let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
		if trimmed.isEmpty {
			return AISummaryService.defaultAPIURLString
		}
		return normalizedAPIURL(from: trimmed)
	}

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		if textField === urlField {
			apiKeyField.becomeFirstResponder()
		} else {
			textField.resignFirstResponder()
		}
		return true
	}
}
