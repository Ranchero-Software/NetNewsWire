//
//  ShareViewController.swift
//  NetNewsWire iOS Share Extension
//
//  Created by Maurice Parker on 9/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import UniformTypeIdentifiers
import Account

// The share extension's principal class (see NSExtensionPrincipalClass in Info.plist).
// A custom form replaces the old SLComposeServiceViewController, which no longer renders correctly.
@objc(ShareViewController)
final class ShareViewController: UINavigationController {

	override func viewDidLoad() {
		super.viewDidLoad()
		viewControllers = [ShareAddFeedViewController()]
	}
}

final class ShareAddFeedViewController: UITableViewController, ShareFolderPickerControllerDelegate {

	private var extensionContainers: ExtensionContainers?
	private var flattenedContainers = [ExtensionContainer]()
	private var selectedContainer: ExtensionContainer?
	private var addFeedButton: UIBarButtonItem?
	private let nameTextField = UITextField()
	private lazy var nameCell = makeNameCell()

	private var url: URL? {
		didSet {
			updateUI()
		}
	}

	private enum Section: Int, CaseIterable {
		case name
		case folder
		case urlDisplay
	}

	init() {
		super.init(style: .insetGrouped)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		title = "NetNewsWire"
		navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel(_:)))
		let addFeedButton = UIBarButtonItem(title: "Add Feed", style: .done, target: self, action: #selector(addFeed(_:)))
		navigationItem.rightBarButtonItem = addFeedButton
		self.addFeedButton = addFeedButton

		tableView.keyboardDismissMode = .onDrag

		extensionContainers = ExtensionContainersFile.read()
		flattenedContainers = extensionContainers?.flattened ?? [ExtensionContainer]()
		if let extensionContainers {
			selectedContainer = ShareDefaultContainer.defaultContainer(containers: extensionContainers)
		}

		updateUI()
		resolveURL()
	}

	// MARK: - Actions

	@objc func cancel(_ sender: Any?) {
		extensionContext?.cancelRequest(withError: CocoaError(.userCancelled))
	}

	@objc func addFeed(_ sender: Any?) {
		guard let url, let selectedContainer, let containerID = selectedContainer.containerID else {
			extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
			return
		}

		let trimmedName = nameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
		let name = (trimmedName?.isEmpty ?? true) ? nil : trimmedName

		let request = ExtensionFeedAddRequest(name: name, feedURL: url, destinationContainerID: containerID)
		ExtensionFeedAddRequestFile.save(request)

		extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
	}

	// MARK: - ShareFolderPickerControllerDelegate

	func shareFolderPickerDidSelect(_ container: ExtensionContainer) {
		ShareDefaultContainer.saveDefaultContainer(container)
		selectedContainer = container
		updateUI()
		navigationController?.popViewController(animated: true)
	}

	// MARK: - Table view

	override func numberOfSections(in tableView: UITableView) -> Int {
		Section.allCases.count
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		1
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		if section == Section.urlDisplay.rawValue {
			return "URL"
		}
		return nil
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		switch Section(rawValue: indexPath.section) {
		case .name:
			return nameCell
		case .folder:
			let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
			var content = UIListContentConfiguration.valueCell()
			content.text = "Folder"
			content.secondaryText = folderValueText
			cell.contentConfiguration = content
			cell.accessoryType = .disclosureIndicator
			return cell
		case .urlDisplay, nil:
			let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
			var content = cell.defaultContentConfiguration()
			content.text = url?.absoluteString ?? ""
			content.textProperties.color = .secondaryLabel
			content.textProperties.numberOfLines = 0
			cell.contentConfiguration = content
			cell.selectionStyle = .none
			return cell
		}
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		guard indexPath.section == Section.folder.rawValue else {
			return
		}

		let folderPickerController = ShareFolderPickerController()
		folderPickerController.title = "Folder"
		folderPickerController.delegate = self
		folderPickerController.containers = flattenedContainers
		folderPickerController.selectedContainerID = selectedContainer?.containerID
		navigationController?.pushViewController(folderPickerController, animated: true)
	}
}

private extension ShareAddFeedViewController {

	var folderValueText: String {
		if let account = selectedContainer as? ExtensionAccount {
			return account.name
		}
		if let folder = selectedContainer as? ExtensionFolder {
			return "\(folder.accountName) / \(folder.name)"
		}
		return ""
	}

	func makeNameCell() -> UITableViewCell {
		let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
		cell.selectionStyle = .none

		nameTextField.placeholder = "Feed Name (Optional)"
		nameTextField.font = .preferredFont(forTextStyle: .body)
		nameTextField.adjustsFontForContentSizeCategory = true
		nameTextField.clearButtonMode = .whileEditing
		nameTextField.autocapitalizationType = .words

		nameTextField.translatesAutoresizingMaskIntoConstraints = false
		cell.contentView.addSubview(nameTextField)
		NSLayoutConstraint.activate([
			nameTextField.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
			nameTextField.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
			nameTextField.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 11),
			nameTextField.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -11)
		])

		return cell
	}

	func updateUI() {
		addFeedButton?.isEnabled = url != nil && selectedContainer != nil
		if isViewLoaded {
			tableView.reloadData()
		}
	}

	// Find the shared URL. It arrives as JavaScript preprocessing results (Safari),
	// a URL item, or plain text that may be a URL.
	func resolveURL() {
		let inputItems = extensionContext?.inputItems as? [NSExtensionItem] ?? []
		let providers = inputItems.compactMap(\.attachments).flatMap { $0 }

		Task { [weak self] in
			if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.propertyList.identifier) }) {
				let item = try? await provider.loadItem(forTypeIdentifier: UTType.propertyList.identifier)
				let results = (item as? NSDictionary)?["NSExtensionJavaScriptPreprocessingResultsKey"] as? NSDictionary
				if let urlString = results?["url"] as? String {
					self?.url = URL(string: urlString)
					return
				}
			}

			if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
				let item = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier)
				if let url = item as? URL {
					self?.url = url
					return
				}
			}

			if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) {
				let item = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier)
				if let text = item as? String {
					self?.url = URL(string: text)
				}
			}
		}
	}
}
