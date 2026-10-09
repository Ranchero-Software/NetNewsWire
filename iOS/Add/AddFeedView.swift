//
//  AddFeedView.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 9/18/26.
//

import SwiftUI
import RSCore
import Account

/// Sheet for subscribing to a feed by URL, with an optional title and a choice of account or folder.
struct AddFeedView: View {

	@Environment(\.dismiss) private var dismiss
	@State private var urlString = ""
	@State private var name = ""
	@State private var container: Container?
	@State private var isAdding = false
	@State private var errorMessage: String?
	@FocusState private var isURLFieldFocused: Bool

	/// When `initialFeed` is nil, a URL on the pasteboard is used if there is one.
	init(initialFeed: String?, initialFeedName: String?) {
		var urlString = initialFeed ?? ""
		if initialFeed == nil, let pasteboardString = UIPasteboard.general.string, pasteboardString.mayBeURL {
			urlString = pasteboardString.normalizedURL
		}
		self._urlString = State(initialValue: urlString)
		self._name = State(initialValue: initialFeedName ?? "")
		self._container = State(initialValue: AddFeedDefaultContainer.defaultContainer)
	}

	var body: some View {
		NavigationStack {
			Form {
				Section {
					TextField(NSLocalizedString("URL", comment: "Label for a feed URL"), text: $urlString)
						.textContentType(.URL)
						.keyboardType(.URL)
						.textInputAutocapitalization(.never)
						.autocorrectionDisabled()
						.focused($isURLFieldFocused)
						.onSubmit {
							isURLFieldFocused = false
						}
					TextField(NSLocalizedString("Title (Optional)", comment: "Feed title placeholder"), text: $name)
						.textInputAutocapitalization(.words)
				}
				Section {
					NavigationLink {
						AddFeedContainerPickerView(selectedContainer: $container)
					} label: {
						LabeledContent(NSLocalizedString("Folder", comment: "Label for choosing the folder a feed is added to"), value: containerName)
					}
				}
			}
			.navigationTitle(NSLocalizedString("Add Feed", comment: "Add Feed"))
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button(NSLocalizedString("Cancel", comment: "Cancel button"), role: .cancel) {
						dismiss()
					}
					.disabled(isAdding)
				}
				ToolbarItem(placement: .confirmationAction) {
					if isAdding {
						ProgressView()
					} else {
						Button(NSLocalizedString("Add", comment: "Add button")) {
							addFeed()
						}
						.disabled(!canAdd)
					}
				}
			}
			.interactiveDismissDisabled(isAdding)
			.errorAlert(message: $errorMessage)
			.onAppear {
				if urlString.isEmpty {
					isURLFieldFocused = true
				}
			}
		}
	}

	private var containerName: String {
		guard let container, let displayName = (container as? DisplayNameProvider)?.nameForDisplay else {
			return ""
		}
		if container is Folder, let accountName = container.account?.nameForDisplay {
			return "\(accountName) / \(displayName)"
		}
		return displayName
	}

	private var canAdd: Bool {
		urlString.mayBeURL && container != nil
	}

	private func addFeed() {
		let normalizedURLString = urlString.normalizedURL
		guard !normalizedURLString.isEmpty, let url = URL(string: normalizedURLString), let container, let account = container.account else {
			return
		}

		if account.hasFeed(withURL: url.absoluteString) {
			errorMessage = AccountError.createErrorAlreadySubscribed.localizedDescription
			return
		}

		isAdding = true
		let feedName = name.isEmpty ? nil : name

		BatchUpdate.shared.start()
		account.createFeed(url: url.absoluteString, name: feedName, container: container, validateFeed: true) { result in
			BatchUpdate.shared.end()
			isAdding = false

			switch result {
			case .success(let feed):
				dismiss()
				NotificationCenter.default.post(name: .UserDidAddFeed, object: nil, userInfo: [UserInfoKey.feed: feed])
			case .failure(let error):
				errorMessage = error.localizedDescription
			}
		}
	}
}
