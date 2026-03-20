//
//  AISummaryPreferencesViewController.swift
//  NetNewsWire
//
//  Created by Codex on 2026/3/20.
//

import AppKit

final class AISummaryPreferencesViewController: NSViewController, NSTextFieldDelegate {

	private let descriptionLabel = NSTextField(labelWithString: NSLocalizedString("Configure an OpenAI-compatible API URL and API Key.", comment: "AI summary description"))
	private let urlLabel = NSTextField(labelWithString: NSLocalizedString("URL", comment: "URL"))
	private let urlField = NSTextField()
	private let apiKeyLabel = NSTextField(labelWithString: NSLocalizedString("API Key", comment: "API Key"))
	private let apiKeyField = NSSecureTextField()
	private let modelLabel = NSTextField(labelWithString: NSLocalizedString("Model", comment: "Model"))
	private let modelPopUpButton = NSPopUpButton()
	private let saveButton = NSButton(title: NSLocalizedString("Save", comment: "Save"), target: nil, action: nil)
	private let statusLabel = NSTextField(labelWithString: "")
	private let settingsLabelWidth: CGFloat = 70

	private var modelReloadWorkItem: DispatchWorkItem?
	private var modelLoadTask: Task<Void, Never>?
	private var lastLoadedSignature: String?
	private var latestRequestedSignature: String?
	private var availableModels = [String]()
	private var isSavingConfiguration = false

	override func loadView() {
		view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 280))
		buildUI()
		reloadValues()
	}

	override func viewWillAppear() {
		super.viewWillAppear()
		reloadValues()
	}
}

extension AISummaryPreferencesViewController {
	func controlTextDidChange(_ obj: Notification) {
		statusLabel.stringValue = ""
		scheduleModelListReload()
	}
}

private extension AISummaryPreferencesViewController {

	func buildUI() {
		descriptionLabel.lineBreakMode = .byWordWrapping
		descriptionLabel.textColor = .secondaryLabelColor

		urlField.placeholderString = AISummaryService.defaultAPIURLString
		apiKeyField.placeholderString = "sk-..."
		urlField.delegate = self
		apiKeyField.delegate = self
		modelPopUpButton.autoenablesItems = false

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

		let modelRow = NSStackView(views: [modelLabel, modelPopUpButton])
		modelRow.orientation = .horizontal
		modelRow.alignment = .firstBaseline
		modelRow.spacing = 12

		for label in [urlLabel, apiKeyLabel, modelLabel] {
			label.setContentHuggingPriority(.required, for: .horizontal)
			label.widthAnchor.constraint(equalToConstant: settingsLabelWidth).isActive = true
		}

		let actionsLeadingSpacer = NSView()
		actionsLeadingSpacer.translatesAutoresizingMaskIntoConstraints = false
		actionsLeadingSpacer.widthAnchor.constraint(equalToConstant: settingsLabelWidth).isActive = true

		let actionsRow = NSStackView(views: [actionsLeadingSpacer, saveButton, statusLabel])
		actionsRow.orientation = .horizontal
		actionsRow.alignment = .centerY
		actionsRow.spacing = 12

		let stack = NSStackView(views: [descriptionStack, urlRow, apiKeyRow, modelRow, actionsRow])
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
		modelPopUpButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true
	}

	func reloadValues() {
		setSavingState(false)
		let storedURL = (UserDefaults.standard.string(forKey: AppDefaults.Key.aiSummaryAPIURL) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
		urlField.stringValue = storedURL.isEmpty ? "" : (normalizedAPIURL(from: storedURL) ?? storedURL)
		apiKeyField.stringValue = AppDefaults.shared.aiSummaryAPIKey
		statusLabel.stringValue = ""
		lastLoadedSignature = nil
		reloadModelList(force: true, preferredModel: AppDefaults.shared.aiSummaryModel)
	}

	@objc func saveSettings(_ sender: Any?) {
		guard !isSavingConfiguration else {
			return
		}

		let apiURLInput = urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
		let apiKey = apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
		let selectedModel = selectedModelForSaving()

		guard let apiURL = effectiveAPIURL(from: apiURLInput) else {
			statusLabel.stringValue = NSLocalizedString("Invalid URL", comment: "Invalid URL")
			statusLabel.textColor = .systemRed
			return
		}

		guard !selectedModel.isEmpty else {
			statusLabel.stringValue = NSLocalizedString("Select a model", comment: "Select model before saving")
			statusLabel.textColor = .systemRed
			return
		}

		guard !apiKey.isEmpty else {
			statusLabel.stringValue = NSLocalizedString("API Key is required", comment: "AI Summary API key required")
			statusLabel.textColor = .systemRed
			return
		}

		setSavingState(true)
		statusLabel.stringValue = NSLocalizedString("Testing model...", comment: "Testing selected model before saving")
		statusLabel.textColor = .secondaryLabelColor

		Task { [weak self] in
			guard let self else {
				return
			}

			do {
				try await AISummaryService.shared.validateModelAvailability(urlString: apiURL, apiKey: apiKey, model: selectedModel)
				await MainActor.run {
					AppDefaults.shared.aiSummaryAPIURL = apiURLInput.isEmpty ? "" : apiURL
					AppDefaults.shared.aiSummaryAPIKey = apiKey
					AppDefaults.shared.aiSummaryModel = selectedModel
					self.urlField.stringValue = apiURLInput.isEmpty ? "" : apiURL
					self.setSavingState(false)
					self.statusLabel.stringValue = NSLocalizedString("Saved", comment: "Saved")
					self.statusLabel.textColor = .systemGreen
				}
			} catch is CancellationError {
				await MainActor.run {
					self.setSavingState(false)
				}
			} catch {
				await MainActor.run {
					self.setSavingState(false)
					self.statusLabel.stringValue = error.localizedDescription
					self.statusLabel.textColor = .systemRed
				}
			}
		}
	}

	func scheduleModelListReload() {
		modelReloadWorkItem?.cancel()

		let workItem = DispatchWorkItem { [weak self] in
			self?.reloadModelList(force: false, preferredModel: self?.currentPreferredModel())
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
		let urlInput = urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
		let apiKey = apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

		guard !apiKey.isEmpty,
			  let normalizedURL = effectiveAPIURL(from: urlInput) else {
			return nil
		}

		return (normalizedURL, apiKey)
	}

	func showModelPlaceholder(_ title: String) {
		availableModels.removeAll()
		modelPopUpButton.removeAllItems()
		modelPopUpButton.addItem(withTitle: title)
		modelPopUpButton.isEnabled = false
	}

	func updateModelSelection(with models: [String], preferredModel: String?) {
		availableModels = models

		guard !models.isEmpty else {
			showModelPlaceholder(NSLocalizedString("No models available", comment: "No models"))
			return
		}

		configureModelPopUp(with: models)
		selectModel(from: models, preferredModel: preferredModel)
	}

	func configureModelPopUp(with models: [String]) {
		modelPopUpButton.removeAllItems()
		modelPopUpButton.addItems(withTitles: models)
		modelPopUpButton.isEnabled = !isSavingConfiguration
	}

	func selectModel(from models: [String], preferredModel: String?) {
		let preferred = (preferredModel ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
		if let preferredIndex = indexOfModel(in: models, model: preferred) {
			modelPopUpButton.selectItem(at: preferredIndex)
			return
		}

		let savedModel = AppDefaults.shared.aiSummaryModel.trimmingCharacters(in: .whitespacesAndNewlines)
		if let savedIndex = indexOfModel(in: models, model: savedModel) {
			modelPopUpButton.selectItem(at: savedIndex)
			return
		}

		modelPopUpButton.selectItem(at: 0)
	}

	func indexOfModel(in models: [String], model: String) -> Int? {
		guard !model.isEmpty else {
			return nil
		}
		return models.firstIndex(of: model)
	}

	func currentPreferredModel() -> String {
		if let selected = modelPopUpButton.titleOfSelectedItem?.trimmingCharacters(in: .whitespacesAndNewlines),
		   !selected.isEmpty {
			return selected
		}
		return AppDefaults.shared.aiSummaryModel
	}

	func selectedModelForSaving() -> String {
		guard let selected = modelPopUpButton.titleOfSelectedItem?.trimmingCharacters(in: .whitespacesAndNewlines),
			  availableModels.contains(selected) else {
			return AppDefaults.shared.aiSummaryModel
		}
		return selected
	}

	func setSavingState(_ isSaving: Bool) {
		isSavingConfiguration = isSaving
		urlField.isEnabled = !isSaving
		apiKeyField.isEnabled = !isSaving
		saveButton.isEnabled = !isSaving
		modelPopUpButton.isEnabled = !isSaving && !availableModels.isEmpty
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
}
