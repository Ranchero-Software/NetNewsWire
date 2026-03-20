//
//  AISummaryPreferencesViewController.swift
//  NetNewsWire
//
//  Created by Codex on 2026/3/20.
//

import AppKit

final class AISummaryPreferencesViewController: NSViewController {

	private let descriptionLabel = NSTextField(labelWithString: NSLocalizedString("Configure an OpenAI-compatible API URL and API Key.", comment: "AI summary description"))
	private let urlLabel = NSTextField(labelWithString: NSLocalizedString("URL", comment: "URL"))
	private let urlField = NSTextField()
	private let apiKeyLabel = NSTextField(labelWithString: NSLocalizedString("API Key", comment: "API Key"))
	private let apiKeyField = NSTextField()
	private let saveButton = NSButton(title: NSLocalizedString("Save", comment: "Save"), target: nil, action: nil)
	private let statusLabel = NSTextField(labelWithString: "")

	override func loadView() {
		view = NSView(frame: NSRect(x: 0, y: 0, width: 450, height: 220))
		buildUI()
		reloadValues()
	}

	override func viewWillAppear() {
		super.viewWillAppear()
		reloadValues()
	}
}

private extension AISummaryPreferencesViewController {

	func buildUI() {
		descriptionLabel.lineBreakMode = .byWordWrapping
		descriptionLabel.textColor = .secondaryLabelColor

		urlField.placeholderString = "https://api.openai.com/v1"
		apiKeyField.placeholderString = "sk-..."

		saveButton.target = self
		saveButton.action = #selector(saveSettings(_:))
		saveButton.bezelStyle = .rounded

		statusLabel.textColor = .secondaryLabelColor

		let descriptionStack = NSStackView(views: [descriptionLabel])
		descriptionStack.orientation = .vertical

		let urlRow = NSStackView(views: [urlLabel, urlField])
		urlRow.orientation = .horizontal
		urlRow.alignment = .firstBaseline
		urlRow.spacing = 12

		let apiKeyRow = NSStackView(views: [apiKeyLabel, apiKeyField])
		apiKeyRow.orientation = .horizontal
		apiKeyRow.alignment = .firstBaseline
		apiKeyRow.spacing = 12

		urlLabel.setContentHuggingPriority(.required, for: .horizontal)
		apiKeyLabel.setContentHuggingPriority(.required, for: .horizontal)
		urlLabel.widthAnchor.constraint(equalToConstant: 70).isActive = true
		apiKeyLabel.widthAnchor.constraint(equalToConstant: 70).isActive = true

		let actionsRow = NSStackView(views: [saveButton, statusLabel])
		actionsRow.orientation = .horizontal
		actionsRow.alignment = .centerY
		actionsRow.spacing = 12

		let stack = NSStackView(views: [descriptionStack, urlRow, apiKeyRow, actionsRow])
		stack.orientation = .vertical
		stack.alignment = .leading
		stack.spacing = 12
		stack.translatesAutoresizingMaskIntoConstraints = false

		view.addSubview(stack)
		NSLayoutConstraint.activate([
			stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
			stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
			stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24)
		])

		urlField.widthAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true
		apiKeyField.widthAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true
	}

	func reloadValues() {
		urlField.stringValue = AppDefaults.shared.aiSummaryAPIURL
		apiKeyField.stringValue = AppDefaults.shared.aiSummaryAPIKey
		statusLabel.stringValue = ""
	}

	@objc func saveSettings(_ sender: Any?) {
		let apiURL = urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
		let apiKey = apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

		guard isValidAPIURL(apiURL) else {
			statusLabel.stringValue = NSLocalizedString("Invalid URL", comment: "Invalid URL")
			statusLabel.textColor = .systemRed
			return
		}

		AppDefaults.shared.aiSummaryAPIURL = apiURL
		AppDefaults.shared.aiSummaryAPIKey = apiKey
		statusLabel.stringValue = NSLocalizedString("Saved", comment: "Saved")
		statusLabel.textColor = .systemGreen
	}

	func isValidAPIURL(_ text: String) -> Bool {
		if let url = URL(string: text), url.scheme != nil {
			return true
		}
		if !text.contains("://"), let url = URL(string: "https://\(text)"), url.scheme != nil {
			return true
		}
		return false
	}
}
