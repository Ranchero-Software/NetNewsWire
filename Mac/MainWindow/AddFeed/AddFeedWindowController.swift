//
//  AddFeedWindowController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/1/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import RSCore
import RSTree
import Articles
import Account

@MainActor protocol AddFeedWindowControllerDelegate: AnyObject {
	// userEnteredURL will have already been validated and normalized.
	func addFeedWindowController(_: AddFeedWindowController, userEnteredURL: URL, userEnteredTitle: String?, container: Container, articleFilter: ArticleFilter?)
	func addFeedWindowControllerUserDidCancel(_: AddFeedWindowController)
}

final class AddFeedWindowController: NSWindowController {
    @IBOutlet var urlTextField: NSTextField!
	@IBOutlet var nameTextField: NSTextField!
	@IBOutlet var addButton: NSButton!
	@IBOutlet var folderPopupButton: NSPopUpButton!

	private var filterKeywordTextField: NSTextField!
	private var filterMatchTypePopup: NSPopUpButton!
	private var filterTagCheckbox: NSButton!
	private var filterTitleCheckbox: NSButton!
	private var filterContentCheckbox: NSButton!
	private var filterSummaryCheckbox: NSButton!

	private var urlString: String?
	private var initialName: String?
	private weak var initialAccount: Account?
	private var initialFolder: Folder?
	private weak var delegate: AddFeedWindowControllerDelegate?
	private var folderTreeController: TreeController!

	private var userEnteredTitle: String? {
		var s = nameTextField.stringValue
		s = s.collapsingWhitespace
		if s.isEmpty {
			return nil
		}
		return s
	}

	private var userEnteredFilter: ArticleFilter? {
		let keyword = filterKeywordTextField.stringValue.trimmingCharacters(in: .whitespaces)
		guard !keyword.isEmpty else {
			return nil
		}
		let matchType: ArticleFilter.MatchType = filterMatchTypePopup.indexOfSelectedItem == 0 ? .contains : .doesNotContain

		var fields = ArticleFilter.MatchFields()
		if filterTagCheckbox.state == .on { fields.insert(.tag) }
		if filterTitleCheckbox.state == .on { fields.insert(.title) }
		if filterContentCheckbox.state == .on { fields.insert(.content) }
		if filterSummaryCheckbox.state == .on { fields.insert(.summary) }
		let matchFields: ArticleFilter.MatchFields? = fields.isEmpty ? nil : fields

		return ArticleFilter(keyword: keyword, matchType: matchType, matchFields: matchFields)
	}

    var hostWindow: NSWindow!

	convenience init(urlString: String?, name: String?, account: Account?, folder: Folder?, folderTreeController: TreeController, delegate: AddFeedWindowControllerDelegate?) {
		self.init(windowNibName: NSNib.Name("AddFeedSheet"))
		self.urlString = urlString
		self.initialName = name
		self.initialAccount = account
		self.initialFolder = folder
		self.delegate = delegate
		self.folderTreeController = folderTreeController
	}

	func runSheetOnWindow(_ hostWindow: NSWindow) {
		guard let window else {
			return
		}
		hostWindow.beginSheet(window)
	}

	override func windowDidLoad() {
		if let urlString = urlString {
			urlTextField.stringValue = urlString
		}
		if let initialName = initialName, !initialName.isEmpty {
			nameTextField.stringValue = initialName
		}

		folderPopupButton.menu = FolderTreeMenu.createFolderPopupMenu(with: folderTreeController.rootNode)

		if let account = initialAccount {
			FolderTreeMenu.select(account: account, folder: initialFolder, in: folderPopupButton)
		} else if let container = AddFeedDefaultContainer.defaultContainer {
			if let folder = container as? Folder, let account = folder.account {
				FolderTreeMenu.select(account: account, folder: folder, in: folderPopupButton)
			} else {
				if let account = container as? Account {
					FolderTreeMenu.select(account: account, folder: nil, in: folderPopupButton)
				}
			}
		}

		addFilterControls()
		updateUI()
	}

    // MARK: Actions

    @IBAction func cancel(_ sender: Any?) {
		cancelSheet()
    }

    @IBAction func addFeed(_ sender: Any?) {
		let urlString = urlTextField.stringValue
		let normalizedURLString = urlString.normalizedURL

		if normalizedURLString.isEmpty {
			cancelSheet()
			return
		}
		guard let url = URL(string: normalizedURLString) else {
			cancelSheet()
			return
		}

		guard let container = selectedContainer() else { return }
		AddFeedDefaultContainer.saveDefaultContainer(container)

		delegate?.addFeedWindowController(self, userEnteredURL: url, userEnteredTitle: userEnteredTitle, container: container, articleFilter: userEnteredFilter)

    }

	@IBAction func localShowFeedList(_ sender: Any?) {
		NSApplication.shared.sendAction(NSSelectorFromString("showFeedList:"), to: nil, from: sender)
		hostWindow.endSheet(window!, returnCode: NSApplication.ModalResponse.continue)
	}

	// MARK: NSTextFieldDelegate

	@objc func controlTextDidEndEditing(_ obj: Notification) {
		updateUI()
	}

	@objc func controlTextDidChange(_ obj: Notification) {
		updateUI()
	}
}

private extension AddFeedWindowController {

	private func updateUI() {
		addButton.isEnabled = urlTextField.stringValue.mayBeURL && selectedContainer() != nil
	}

	func addFilterControls() {
		guard let contentView = window?.contentView else {
			return
		}

		// "Filter:" label
		let filterLabel = NSTextField(labelWithString: "Filter:")
		filterLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
		filterLabel.alignment = .right
		filterLabel.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(filterLabel)

		// Keyword text field
		let keywordField = NSTextField()
		keywordField.placeholderString = "Optional keyword (e.g. AI, space, podcast)"
		keywordField.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(keywordField)
		self.filterKeywordTextField = keywordField

		// Match type popup
		let matchPopup = NSPopUpButton()
		matchPopup.addItems(withTitles: [
			"Hide articles with keyword",
			"Only show articles with keyword"
		])
		matchPopup.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(matchPopup)
		self.filterMatchTypePopup = matchPopup

		// "Match in:" label
		let matchInLabel = NSTextField(labelWithString: "Match in:")
		matchInLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
		matchInLabel.alignment = .right
		matchInLabel.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(matchInLabel)

		// Field checkboxes
		let tagCheck = NSButton(checkboxWithTitle: "Tag", target: nil, action: nil)
		tagCheck.state = .on
		tagCheck.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(tagCheck)
		self.filterTagCheckbox = tagCheck

		let titleCheck = NSButton(checkboxWithTitle: "Title", target: nil, action: nil)
		titleCheck.state = .on
		titleCheck.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(titleCheck)
		self.filterTitleCheckbox = titleCheck

		let contentCheck = NSButton(checkboxWithTitle: "Content", target: nil, action: nil)
		contentCheck.state = .on
		contentCheck.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(contentCheck)
		self.filterContentCheckbox = contentCheck

		let summaryCheck = NSButton(checkboxWithTitle: "Summary", target: nil, action: nil)
		summaryCheck.state = .on
		summaryCheck.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(summaryCheck)
		self.filterSummaryCheckbox = summaryCheck

		// Remove the existing bottom constraint on the Add button
		for constraint in contentView.constraints {
			let involvesAddButton = (constraint.firstItem === addButton || constraint.secondItem === addButton)
			let involvesBottom = (constraint.firstAttribute == .bottom || constraint.secondAttribute == .bottom)
			if involvesAddButton && involvesBottom {
				contentView.removeConstraint(constraint)
			}
		}

		// Layout
		NSLayoutConstraint.activate([
			// Filter label + keyword field
			filterLabel.trailingAnchor.constraint(equalTo: folderPopupButton.leadingAnchor, constant: -8),
			filterLabel.firstBaselineAnchor.constraint(equalTo: keywordField.firstBaselineAnchor),

			keywordField.leadingAnchor.constraint(equalTo: folderPopupButton.leadingAnchor),
			keywordField.trailingAnchor.constraint(equalTo: folderPopupButton.trailingAnchor),
			keywordField.topAnchor.constraint(equalTo: folderPopupButton.bottomAnchor, constant: 10),

			// Match type popup
			matchPopup.leadingAnchor.constraint(equalTo: folderPopupButton.leadingAnchor),
			matchPopup.trailingAnchor.constraint(equalTo: folderPopupButton.trailingAnchor),
			matchPopup.topAnchor.constraint(equalTo: keywordField.bottomAnchor, constant: 6),

			// "Match in:" label + checkboxes row
			matchInLabel.trailingAnchor.constraint(equalTo: folderPopupButton.leadingAnchor, constant: -8),
			matchInLabel.firstBaselineAnchor.constraint(equalTo: tagCheck.firstBaselineAnchor),

			tagCheck.leadingAnchor.constraint(equalTo: folderPopupButton.leadingAnchor),
			tagCheck.topAnchor.constraint(equalTo: matchPopup.bottomAnchor, constant: 8),

			titleCheck.leadingAnchor.constraint(equalTo: tagCheck.trailingAnchor, constant: 12),
			titleCheck.firstBaselineAnchor.constraint(equalTo: tagCheck.firstBaselineAnchor),

			contentCheck.leadingAnchor.constraint(equalTo: titleCheck.trailingAnchor, constant: 12),
			contentCheck.firstBaselineAnchor.constraint(equalTo: tagCheck.firstBaselineAnchor),

			summaryCheck.leadingAnchor.constraint(equalTo: contentCheck.trailingAnchor, constant: 12),
			summaryCheck.firstBaselineAnchor.constraint(equalTo: tagCheck.firstBaselineAnchor),

			// Buttons below checkboxes
			addButton.topAnchor.constraint(equalTo: tagCheck.bottomAnchor, constant: 20),
			contentView.bottomAnchor.constraint(equalTo: addButton.bottomAnchor, constant: 20),
		])

		// Resize window to fit new content
		if let window {
			var frame = window.frame
			frame.size.height += 100
			frame.origin.y -= 100
			window.setFrame(frame, display: false)
		}
	}

	func cancelSheet() {
		delegate?.addFeedWindowControllerUserDidCancel(self)
	}

	func selectedContainer() -> Container? {
		guard folderPopupButton.selectedItem?.isEnabled ?? false else { return nil }
		return folderPopupButton.selectedItem?.representedObject as? Container
	}
}
