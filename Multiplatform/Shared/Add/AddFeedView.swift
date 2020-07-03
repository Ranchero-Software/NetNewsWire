//
//  AddFeedView.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 3/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import RSCore

fileprivate enum AddFeedError: LocalizedError {
	
	case none, alreadySubscribed, initialDownload, noFeeds
	
	var errorDescription: String? {
		switch self {
		case .alreadySubscribed:
			return NSLocalizedString("Can’t add this feed because you’ve already subscribed to it.", comment: "Feed finder")
		case .initialDownload:
			return NSLocalizedString("Can’t add this feed because of a download error.", comment: "Feed finder")
		case .noFeeds:
			return NSLocalizedString("Can’t add a feed because no feed was found.", comment: "Feed finder")
		default:
			return nil
		}
	}
	
}

fileprivate class AddFeedViewModel: ObservableObject {
	
	@Published var providedURL: String = ""
	@Published var providedName: String = ""
	@Published var selectedFolderIndex: Int = 0
	@Published var addFeedError: AddFeedError? {
		didSet {
			addFeedError != .none ? (showError = true) : (showError = false)
		}
	}
	@Published var showError: Bool = false
	@Published var containers: [Container] = []
	@Published var showProgressIndicator: Bool = false
	
	init() {
		for account in AccountManager.shared.sortedActiveAccounts {
			containers.append(account)
			if let sortedFolders = account.sortedFolders {
				containers.append(contentsOf: sortedFolders)
			}
		}
	}
	
}

struct AddFeedView: View {
	
	@Environment(\.presentationMode) private var presentationMode
	@ObservedObject private var viewModel = AddFeedViewModel()
	
    @ViewBuilder var body: some View {
		#if os(iOS)
			iosForm
		#else
			macForm
				.onAppear {
					pasteUrlFromPasteboard()
				}.alert(isPresented: $viewModel.showError) {
					Alert(title: Text("Oops"), message: Text(viewModel.addFeedError!.localizedDescription), dismissButton: Alert.Button.cancel({
						viewModel.addFeedError = .none
					}))
				}
		#endif
    }
	
	#if os(macOS)
	var macForm: some View {
		VStack(alignment: .leading) {
			HStack {
				Spacer()
				Image(systemName: "globe").foregroundColor(.accentColor).font(.title)
				Text("Add a Web Feed")
					.font(.title)
				Spacer()
			}
			urlTextField
				.textFieldStyle(RoundedBorderTextFieldStyle())
				.help("The URL of the feed you want to add.")
			providedNameTextField
				.textFieldStyle(RoundedBorderTextFieldStyle())
				.help("The name of the feed. (Optional.)")
			folderPicker
				.help("Pick the folder you want to add the feed to.")
			buttonStack
		}
		.padding()
		.frame(minWidth: 450)
	}
	#endif
	
	#if os(iOS)
	var iosForm: some View {
		NavigationLink {
			List {
				Text("PLACEHOLDER")
			}.listStyle(InsetGroupedListStyle())
		}
	}
	#endif
	
	var urlTextField: some View {
		HStack {
			Text("Feed:  ").font(.system(.body, design: .monospaced))
			TextField("URL", text: $viewModel.providedURL)
		}
	}
	
	var providedNameTextField: some View {
		HStack(alignment: .lastTextBaseline) {
			Text("Name:  ").font(.system(.body, design: .monospaced))
			TextField("Optional", text: $viewModel.providedName)
		}
	}
	
	var folderPicker: some View {
		Picker("Folder:", selection: $viewModel.selectedFolderIndex, content: {
			ForEach(0..<viewModel.containers.count, id: \.self, content: { index in
				if let containerName = (viewModel.containers[index] as? DisplayNameProvider)?.nameForDisplay {
					if viewModel.containers[index] is Folder {
						Text("\(viewModel.containers[index].account?.nameForDisplay ?? "") / \(containerName)").tag(index)
					} else {
						Text(containerName).tag(index)
					}
				}
			})
		}).font(.system(.body, design: .monospaced))
	}
	
	var buttonStack: some View {
		HStack {
			if viewModel.showProgressIndicator == true {
				ProgressView()
					.frame(width: 25, height: 25)
					.help("Adding Feed")
			}
			Spacer()
			Button("Cancel", action: {
				presentationMode.wrappedValue.dismiss()
			})
			.help("Cancel Add Feed")
			
			Button("Add", action: {
				addWebFeed()
			})
			.disabled(!viewModel.providedURL.isValidURL)
			.help("Add Feed")
		}
	}
	
	#if os(macOS)
	func pasteUrlFromPasteboard() {
		guard let stringFromPasteboard = urlStringFromPasteboard, stringFromPasteboard.isValidURL else {
			return
		}
		viewModel.providedURL = stringFromPasteboard
	}
	#endif
	
}

private extension AddFeedView {

	var urlStringFromPasteboard: String? {
		if let urlString = NSPasteboard.urlString(from: NSPasteboard.general) {
			return urlString.normalizedURL
		}
		return nil
	}
	
	struct AccountAndFolderSpecifier {
		let account: Account
		let folder: Folder?
	}

	func accountAndFolderFromContainer(_ container: Container) -> AccountAndFolderSpecifier? {
		if let account = container as? Account {
			return AccountAndFolderSpecifier(account: account, folder: nil)
		}
		if let folder = container as? Folder, let account = folder.account {
			return AccountAndFolderSpecifier(account: account, folder: folder)
		}
		return nil
	}
	
	func addWebFeed() {
		if let account = accountAndFolderFromContainer(viewModel.containers[viewModel.selectedFolderIndex])?.account {
			
			viewModel.showProgressIndicator = true
			
			let container = viewModel.containers[viewModel.selectedFolderIndex]
			
			if account.hasWebFeed(withURL: viewModel.providedURL) {
				viewModel.addFeedError = .alreadySubscribed
				viewModel.showProgressIndicator = false
				return
			}
			
			account.createWebFeed(url: viewModel.providedURL, name: viewModel.providedName, container: container, completion: { result in
				viewModel.showProgressIndicator = false
				switch result {
				case .success(let feed):
					NotificationCenter.default.post(name: .UserDidAddFeed, object: self, userInfo: [UserInfoKey.webFeed: feed])
					presentationMode.wrappedValue.dismiss()
				case .failure(let error):
					switch error {
					case AccountError.createErrorAlreadySubscribed:
						self.viewModel.addFeedError = .alreadySubscribed
						return
					case AccountError.createErrorNotFound:
						self.viewModel.addFeedError = .noFeeds
						return
					default:
						print("Error")
					}
				}
			})
		}
	}
}


struct AddFeedView_Previews: PreviewProvider {
    static var previews: some View {
        AddFeedView()
    }
}
