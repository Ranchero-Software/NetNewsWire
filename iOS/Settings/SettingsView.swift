//
//  SettingsView.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 11/14/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers
import RSCore
import Account

struct SettingsView: View {

	/// Pushes the Timeline screen on appearing, so a user can turn off the Mark All as Read confirmation.
	let showTimelineSettings: Bool
	/// Presents Settings, and presents what Settings hands off to after dismissing itself.
	let presentingParentController: RootSplitViewController?

	@State private var model = SettingsModel()
	@State private var path = [SettingsDestination]()
	@State private var didShowTimelineSettings = false
	@State private var opmlAccount: Account?
	@State private var isShowingImportAccountChoices = false
	@State private var isShowingExportAccountChoices = false
	@State private var isShowingOPMLImporter = false
	@State private var opmlExportURL: URL?
	@State private var safariURL: URL?
	@State private var alert: SettingsAlert?

	@MainActor private static let buildLabelFont = UIFont.systemFont(ofSize: 11.0)

	var body: some View {
		NavigationStack(path: $path) {
			List {
				Section(SettingsSection.notifications.title) {
					actionRow(.systemSettings) {
						openSystemSettings()
					}
				}
				Section(SettingsSection.accounts.title) {
					ForEach(model.accounts, id: \.accountID) { account in
						navigationRow(.account(account), destination: .account(accountID: account.accountID))
					}
					navigationRow(.addAccount, destination: .addAccount)
				}
				Section(SettingsSection.feeds.title) {
					actionRow(.importSubscriptions) {
						importSubscriptions()
					}
					.confirmationDialog(NSLocalizedString("Choose an account to receive the imported feeds and folders", comment: "Import Account"), isPresented: $isShowingImportAccountChoices, titleVisibility: .visible) {
						ForEach(AccountManager.shared.sortedActiveAccounts, id: \.accountID) { account in
							Button(account.nameForDisplay) {
								opmlAccount = account
								isShowingOPMLImporter = true
							}
						}
						Button(NSLocalizedString("Cancel", comment: "Cancel button"), role: .cancel) {
						}
					}
					actionRow(.exportSubscriptions) {
						exportSubscriptions()
					}
					.confirmationDialog(NSLocalizedString("Choose an account with the subscriptions to export", comment: "Export Account"), isPresented: $isShowingExportAccountChoices, titleVisibility: .visible) {
						ForEach(AccountManager.shared.sortedAccounts, id: \.accountID) { account in
							Button(account.nameForDisplay) {
								exportOPML(account)
							}
						}
						Button(NSLocalizedString("Cancel", comment: "Cancel button"), role: .cancel) {
						}
					}
					if model.showAddNetNewsWireNewsFeed {
						actionRow(.addNetNewsWireNewsFeed) {
							addNetNewsWireNewsFeed()
						}
					}
				}
				Section(SettingsSection.appearance.title) {
					navigationRow(.general, destination: .general)
					navigationRow(.sidebar, destination: .sidebar)
					navigationRow(.timeline, destination: .timeline)
					navigationRow(.articles, destination: .articles)
				}
				Section(SettingsSection.troubleshooting.title) {
					navigationRow(.errorLog, destination: .errorLog)
					navigationRow(.activityLog, destination: .activityLog)
					navigationRow(.accountStats, destination: .accountStats)
					navigationRow(.dinosaurs, destination: .dinosaurs)
					if model.showCloudKitStats {
						navigationRow(.cloudKitStats, destination: .cloudKitStats)
					}
				}
				Section {
					actionRow(.help) {
						openURL(HelpURL.helpHome.rawValue)
					}
					actionRow(.forum) {
						openURL(HelpURL.discourse.rawValue)
					}
					actionRow(.releaseNotes) {
						openURL(HelpURL.releaseNotes.rawValue)
					}
					actionRow(.bugTracker) {
						openURL(HelpURL.bugTracker.rawValue)
					}
					navigationRow(.about, destination: .about)
				} header: {
					Text(SettingsSection.help.title)
				} footer: {
					CopyableText(text: "\(Bundle.main.appName) \(Bundle.main.versionNumber) (build \(Bundle.main.buildNumber))", font: Self.buildLabelFont, textColor: UIColor.gray, textAlignment: .natural)
				}
			}
			.navigationTitle(NSLocalizedString("Settings", comment: "Settings"))
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					doneButton
				}
			}
			.navigationDestination(for: SettingsDestination.self) { destination in
				destinationView(destination)
			}
		}
		.onAppear {
			if showTimelineSettings && !didShowTimelineSettings {
				didShowTimelineSettings = true
				path.append(.timeline)
			}
		}
		.fileImporter(isPresented: $isShowingOPMLImporter, allowedContentTypes: Self.opmlContentTypes) { result in
			if case .success(let url) = result, let opmlAccount {
				importOPML(url, into: opmlAccount)
			}
		}
		.fileMover(isPresented: isShowingOPMLExporter, file: opmlExportURL) { _ in
		}
		.sheet(isPresented: isShowingSafari) {
			if let safariURL {
				SafariView(url: safariURL)
			}
		}
		.alert(alert?.title ?? "", isPresented: isShowingAlert, presenting: alert) { _ in
			Button(NSLocalizedString("OK", comment: "OK button")) {
			}
		} message: { alert in
			Text(verbatim: alert.message)
		}
	}
}

// MARK: - Rows

private extension SettingsView {

	func rowLabel(_ row: SettingsRow) -> some View {
		Label {
			Text(row.title)
				.foregroundStyle(.primary)
		} icon: {
			Image(uiImage: row.iconImage)
				.foregroundStyle(Color(uiColor: Assets.Colors.primaryAccent))
		}
	}

	func navigationRow(_ row: SettingsRow, destination: SettingsDestination) -> some View {
		NavigationLink(value: destination) {
			rowLabel(row)
		}
	}

	func actionRow(_ row: SettingsRow, action: @escaping () -> Void) -> some View {
		Button(action: action) {
			rowLabel(row)
		}
	}

	@ViewBuilder var doneButton: some View {
		if #available(iOS 26, *) {
			Button(NSLocalizedString("Done", comment: "Done"), systemImage: "checkmark") {
				presentingParentController?.dismiss(animated: true)
			}
		} else {
			Button(NSLocalizedString("Done", comment: "Done")) {
				presentingParentController?.dismiss(animated: true)
			}
		}
	}

	@ViewBuilder func destinationView(_ destination: SettingsDestination) -> some View {
		switch destination {
		case .account(let accountID):
			if let account = AccountManager.shared.existingAccount(accountID: accountID) {
				AccountInspectorView(account: account, isModal: false, close: {
					popDestination()
				})
			}
		case .addAccount:
			AddAccountView(presentationAnchor: presentingParentController?.view.window) {
				var transaction = Transaction()
				transaction.disablesAnimations = true
				withTransaction(transaction) {
					popDestination()
				}
			}
		case .general:
			GeneralSettingsView()
		case .sidebar:
			SidebarSettingsView()
		case .timeline:
			TimelineSettingsRepresentable()
				.ignoresSafeArea()
				.navigationTitle(NSLocalizedString("Timeline", comment: "Timeline"))
		case .articles:
			ArticlesSettingsView(importTheme: { url in
				guard let settingsController = presentingParentController?.presentedViewController else {
					return
				}
				try ArticleThemeImporter.importTheme(controller: settingsController, url: url)
			})
		case .errorLog:
			ErrorLogView()
		case .activityLog:
			ActivityLogView()
		case .accountStats:
			AccountStatsView()
		case .dinosaurs:
			DinosaursView(dismissAndPresent: { dinosaur in
				presentingParentController?.dismiss(animated: true) {
					presentingParentController?.coordinator.discloseFeed(dinosaur.feed, animations: [.scroll, .navigation])
				}
			})
		case .cloudKitStats:
			CloudKitStatsView()
		case .about:
			AboutView()
		}
	}

	func popDestination() {
		if !path.isEmpty {
			path.removeLast()
		}
	}
}

// MARK: - Actions

private extension SettingsView {

	static var opmlContentTypes: [UTType] {
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

		return contentTypes
	}

	var isShowingOPMLExporter: Binding<Bool> {
		Binding {
			opmlExportURL != nil
		} set: { isShowing in
			if !isShowing {
				opmlExportURL = nil
			}
		}
	}

	var isShowingSafari: Binding<Bool> {
		Binding {
			safariURL != nil
		} set: { isShowing in
			if !isShowing {
				safariURL = nil
			}
		}
	}

	var isShowingAlert: Binding<Bool> {
		Binding {
			alert != nil
		} set: { isShowing in
			if !isShowing {
				alert = nil
			}
		}
	}

	func openSystemSettings() {
		if let url = URL(string: UIApplication.openSettingsURLString) {
			UIApplication.shared.open(url)
		}
	}

	func addNetNewsWireNewsFeed() {
		presentingParentController?.dismiss(animated: true)

		let addFeedView = AddFeedView(initialFeed: AccountManager.netNewsWireNewsURL, initialFeedName: NSLocalizedString("NetNewsWire News", comment: "NetNewsWire News"))
		let hostingController = UIHostingController(rootView: addFeedView)
		hostingController.modalPresentationStyle = .formSheet
		hostingController.preferredContentSize = UIViewController.formSheetSize

		presentingParentController?.present(hostingController, animated: true)
	}

	func importSubscriptions() {
		switch AccountManager.shared.activeAccounts.count {
		case 0:
			alert = SettingsAlert(title: NSLocalizedString("Error", comment: "Error"), message: NSLocalizedString("You must have at least one active account.", comment: "Missing active account"))
		case 1:
			opmlAccount = AccountManager.shared.activeAccounts.first
			isShowingOPMLImporter = true
		default:
			isShowingImportAccountChoices = true
		}
	}

	func importOPML(_ url: URL, into account: Account) {
		// Access lasts until the import, which reads the file, finishes.
		let isAccessingSecurityScopedResource = url.startAccessingSecurityScopedResource()
		account.importOPML(url) { result in
			if isAccessingSecurityScopedResource {
				url.stopAccessingSecurityScopedResource()
			}
			if case .failure = result {
				let title = NSLocalizedString("Import Failed", comment: "Import Failed")
				let message = NSLocalizedString("We were unable to process the selected file.  Please ensure that it is a properly formatted OPML file.", comment: "Import Failed Message")
				alert = SettingsAlert(title: title, message: message)
			}
		}
	}

	func exportSubscriptions() {
		if AccountManager.shared.accounts.count == 1, let account = AccountManager.shared.accounts.first {
			exportOPML(account)
		} else {
			isShowingExportAccountChoices = true
		}
	}

	func exportOPML(_ account: Account) {
		let accountName = account.nameForDisplay.replacingOccurrences(of: " ", with: "").trimmingCharacters(in: .whitespaces)
		let filename = "Subscriptions-\(accountName).opml"
		let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
		do {
			try account.logActivity(kind: .exportOPML, detail: filename) {
				let opmlString = OPMLExporter.OPMLString(with: account, title: filename)
				try opmlString.write(to: tempFile, atomically: true, encoding: String.Encoding.utf8)
			}
		} catch {
			alert = SettingsAlert(title: "OPML Export Error", message: error.localizedDescription)
			return
		}
		opmlExportURL = tempFile
	}

	func openURL(_ urlString: String) {
		guard let url = URL(string: urlString) else {
			return
		}

		// Open GitHub links in the GitHub app when installed.
		if let host = url.host, host == "github.com" || host.hasSuffix(".github.com") {
			Task {
				let openedInApp = await UIApplication.shared.open(url, options: [.universalLinksOnly: true])
				if !openedInApp {
					safariURL = url
				}
			}
			return
		}

		safariURL = url
	}
}

// MARK: - SettingsModel

/// Tracks the accounts and the rows that depend on them, updating when accounts change.
@MainActor @Observable final class SettingsModel {

	private(set) var accounts = [Account]()
	private(set) var showAddNetNewsWireNewsFeed = false
	private(set) var showCloudKitStats = false

	init() {
		update()

		NotificationCenter.default.addObserver(self, selector: #selector(handleUserDidAddAccount(_:)), name: .UserDidAddAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleUserDidDeleteAccount(_:)), name: .UserDidDeleteAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleDisplayNameDidChange(_:)), name: .DisplayNameDidChange, object: nil)
	}

	@objc func handleUserDidAddAccount(_ notification: Notification) {
		update()
	}

	@objc func handleUserDidDeleteAccount(_ notification: Notification) {
		update()
	}

	@objc func handleDisplayNameDidChange(_ notification: Notification) {
		update()
	}
}

private extension SettingsModel {

	func update() {
		accounts = AccountManager.shared.sortedAccounts
		showAddNetNewsWireNewsFeed = !AccountManager.shared.activeAccounts.isEmpty && !AccountManager.shared.anyAccountHasNetNewsWireNewsSubscription()
		showCloudKitStats = AccountManager.shared.hasiCloudAccount
	}
}

// MARK: - Sections, Rows, and Destinations

private enum SettingsSection {
	case notifications
	case accounts
	case feeds
	case appearance
	case troubleshooting
	case help

	var title: String {
		switch self {
		case .notifications:
			NSLocalizedString("Notifications, Badge, Data, & More", comment: "Notifications, Badge, Data, & More")
		case .accounts:
			NSLocalizedString("Accounts", comment: "Preferences")
		case .feeds:
			NSLocalizedString("Feeds", comment: "Feeds")
		case .appearance:
			NSLocalizedString("Appearance", comment: "Preferences")
		case .troubleshooting:
			NSLocalizedString("Troubleshooting", comment: "Troubleshooting")
		case .help:
			NSLocalizedString("Help", comment: "Help")
		}
	}
}

@MainActor private enum SettingsRow {
	case systemSettings
	case account(Account)
	case addAccount
	case importSubscriptions
	case exportSubscriptions
	case addNetNewsWireNewsFeed
	case general
	case sidebar
	case timeline
	case articles
	case errorLog
	case activityLog
	case accountStats
	case dinosaurs
	case cloudKitStats
	case help
	case forum
	case releaseNotes
	case bugTracker
	case about

	var title: String {
		switch self {
		case .systemSettings:
			NSLocalizedString("Open System Settings", comment: "Open System Settings button")
		case .account(let account):
			account.nameForDisplay
		case .addAccount:
			NSLocalizedString("Add Account", comment: "Add Account")
		case .importSubscriptions:
			NSLocalizedString("Import Subscriptions", comment: "Import Subscriptions")
		case .exportSubscriptions:
			NSLocalizedString("Export Subscriptions", comment: "Export Subscriptions")
		case .addNetNewsWireNewsFeed:
			NSLocalizedString("Add NetNewsWire News Feed", comment: "Add NetNewsWire News Feed")
		case .general:
			NSLocalizedString("General", comment: "Preferences")
		case .sidebar:
			NSLocalizedString("Sidebar", comment: "Sidebar")
		case .timeline:
			NSLocalizedString("Timeline", comment: "Timeline")
		case .articles:
			NSLocalizedString("Articles", comment: "Articles")
		case .errorLog:
			NSLocalizedString("Error Log", comment: "Error Log window title")
		case .activityLog:
			NSLocalizedString("Activity Log", comment: "Activity Log screen title")
		case .accountStats:
			NSLocalizedString("Account Stats", comment: "Account Stats screen title")
		case .dinosaurs:
			NSLocalizedString("Dinosaurs", comment: "Dinosaurs")
		case .cloudKitStats:
			NSLocalizedString("iCloud Storage Stats", comment: "iCloud Storage Stats window title")
		case .help:
			NSLocalizedString("NetNewsWire Help", comment: "NetNewsWire Help")
		case .forum:
			NSLocalizedString("NetNewsWire Forum", comment: "NetNewsWire Forum")
		case .releaseNotes:
			NSLocalizedString("Release Notes", comment: "Release Notes")
		case .bugTracker:
			NSLocalizedString("Bug Tracker", comment: "Bug Tracker")
		case .about:
			NSLocalizedString("About NetNewsWire", comment: "About NetNewsWire")
		}
	}

	var iconImage: UIImage {
		switch self {
		case .systemSettings:
			Assets.Images.settingsSystemSettings
		case .account(let account):
			Assets.Images.settingsAccountImage(account.type)
		case .addAccount:
			Assets.Images.plus
		case .importSubscriptions:
			Assets.Images.settingsImportSubscriptions
		case .exportSubscriptions:
			Assets.Images.settingsExportSubscriptions
		case .addNetNewsWireNewsFeed:
			Assets.Images.settingsNetNewsWireNewsFeed
		case .general:
			Assets.Images.preferencesToolbarAppearance
		case .sidebar:
			Assets.Images.settingsSidebar
		case .timeline:
			Assets.Images.settingsTimeline
		case .articles:
			Assets.Images.settingsArticles
		case .errorLog:
			Assets.Images.settingsErrorLog
		case .activityLog:
			Assets.Images.settingsActivityLog
		case .accountStats:
			Assets.Images.settingsAccountStats
		case .dinosaurs:
			Assets.Images.settingsDinosaurs
		case .cloudKitStats:
			Assets.Images.settingsCloudKitStats
		case .help:
			Assets.Images.settingsHelp
		case .forum:
			Assets.Images.settingsForum
		case .releaseNotes:
			Assets.Images.settingsReleaseNotes
		case .bugTracker:
			Assets.Images.settingsBugTracker
		case .about:
			Assets.Images.info
		}
	}
}

private enum SettingsDestination: Hashable {
	case account(accountID: String)
	case addAccount
	case general
	case sidebar
	case timeline
	case articles
	case errorLog
	case activityLog
	case accountStats
	case dinosaurs
	case cloudKitStats
	case about
}

private struct SettingsAlert {
	let title: String
	let message: String
}

/// The Timeline settings screen stays UIKit, since its previews are real timeline cells.
private struct TimelineSettingsRepresentable: UIViewControllerRepresentable {

	func makeUIViewController(context: Context) -> TimelineSettingsViewController {
		TimelineSettingsViewController()
	}

	func updateUIViewController(_ timelineSettingsViewController: TimelineSettingsViewController, context: Context) {
	}
}
