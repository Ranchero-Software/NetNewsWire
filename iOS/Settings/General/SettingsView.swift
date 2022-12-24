//
//  SettingsView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 12/11/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
	
	@Environment(\.dismiss) var dismiss
	@StateObject private var appDefaults = AppDefaults.shared
	@StateObject private var viewModel = SettingsViewModel()
	
	@Binding var isConfigureAppearanceShown: Bool
		
	var body: some View {
		NavigationView {
			List {
				// Device Permissions
				Section(header: Text("Device Permissions", comment: "Settings: Device Permissions section header."),
						footer: Text("Configure NetNewsWire's access to Siri, background app refresh, mobile data, and more.", comment: "Settings: Device Permissions section footer.")) {
					SettingsViewRows.openSystemSettings
				}
				
				// Account/Extensions/OPML Management
				Section(header: Text("Accounts & Extensions", comment: "Settings: Accounts and Extensions section header."),
						footer: Text("Add, delete, enable, or disable accounts and extensions.", comment: "Settings: Accounts and Extensions section footer.")) {
					SettingsViewRows.addAccount
					SettingsViewRows.manageExtensions
					SettingsViewRows.importOPML(showImportActionSheet: $viewModel.showImportActionSheet)
						.confirmationDialog(Text("Choose an account to receive the imported feeds and folders", comment: "Import OPML confirmation title."),
											isPresented: $viewModel.showImportActionSheet,
											titleVisibility: .visible) {
							ForEach(AccountManager.shared.sortedActiveAccounts, id: \.self) { account in
								Button(account.nameForDisplay) {
									viewModel.importAccount = account
									viewModel.showImportView = true
								}
							}
						}
					
					SettingsViewRows.exportOPML(showExportActionSheet: $viewModel.showExportActionSheet)
						.confirmationDialog(Text("Choose an account with the subscriptions to export", comment: "Export OPML confirmation title."),
											isPresented: $viewModel.showExportActionSheet,
											titleVisibility: .visible) {
							ForEach(AccountManager.shared.sortedAccounts, id: \.self) { account in
								Button(account.nameForDisplay) {
									do {
										let document = try OPMLDocument(account)
										viewModel.exportDocument = document
										viewModel.showExportView = true
									} catch {
										viewModel.importExportError = error
										viewModel.showImportExportError = true
									}
								}
							}
						}
				}
				
				// Appearance
				Section(header: Text("Appearance", comment: "Settings: Appearance section header."),
						footer: Text("Manage the look, feel, and behavior of NetNewsWire.", comment: "Settings: Appearance section footer.")) {
					SettingsViewRows.configureAppearance($isConfigureAppearanceShown)
					if viewModel.notificationPermissions == .authorized {
						SettingsViewRows.configureNewArticleNotifications
					}
				}
				
				// Help
				Section {
					ForEach(0..<HelpSheet.allCases.count, id: \.self) { i in
						SettingsViewRows.showHelpSheet(sheet: HelpSheet.allCases[i], selectedSheet: $viewModel.helpSheet, $viewModel.showHelpSheet)
					}
					SettingsViewRows.aboutNetNewsWire
				}
			}
			.tint(Color(uiColor: AppAssets.primaryAccentColor))
			.listStyle(.insetGrouped)
			.navigationTitle(Text("Settings", comment: "Navigation bar title for Settings."))
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .navigationBarLeading, content: {
					Button(action: { dismiss() }, label: { Text("Done", comment: "Button title") })
				})
			}
			.sheet(isPresented: $viewModel.showAddAccountView) {
				AddAccountListView()
			}
			.sheet(isPresented: $viewModel.showHelpSheet) {
				SafariView(url: viewModel.helpSheet.url)
			}
			.sheet(isPresented: $viewModel.showAbout) {
				AboutView()
			}
			.task {
				UNUserNotificationCenter.current().getNotificationSettings { settings in
					DispatchQueue.main.async {
						self.viewModel.notificationPermissions = settings.authorizationStatus
					}
				}
			}
			.onReceive(NotificationCenter.default.publisher(for: UIScene.willEnterForegroundNotification)) { _ in
				UNUserNotificationCenter.current().getNotificationSettings { settings in
					DispatchQueue.main.async {
						self.viewModel.notificationPermissions = settings.authorizationStatus
					}
				}
			}
			.dismissOnExternalContextLaunch()
			.fileImporter(isPresented: $viewModel.showImportView, allowedContentTypes: OPMLDocument.readableContentTypes) { result in
				switch result {
				case .success(let url):
					if url.startAccessingSecurityScopedResource() {
						viewModel.importAccount!.importOPML(url) { importResult in
							switch importResult {
							case .success(_):
								viewModel.showImportSuccess = true
								url.stopAccessingSecurityScopedResource()
							case .failure(let error):
								viewModel.importExportError = error
								viewModel.showImportExportError = true
								url.stopAccessingSecurityScopedResource()
							}
						}
					}
				case .failure(let error):
					viewModel.importExportError = error
					viewModel.showImportExportError = true
				}
			}
			.fileExporter(isPresented: $viewModel.showExportView, document: viewModel.exportDocument, contentType: OPMLDocument.writableContentTypes.first!, onCompletion: { result in
				switch result {
				case .success(_):
					viewModel.showExportSuccess = true
				case .failure(let error):
					viewModel.importExportError = error
					viewModel.showImportExportError = true
				}
			})
			.alert(Text("Imported Successfully", comment: "Alert title: imported OPML file successfully."),
				   isPresented: $viewModel.showImportSuccess,
				   actions: {},
				   message: { Text("Subscriptions have been imported to your \(viewModel.importAccount?.nameForDisplay ?? "") account.", comment: "Alert message: imported OPML file successfully.") })
			.alert(Text("Exported Successfully", comment: "Alert title: exported OPML file successfully."),
				   isPresented: $viewModel.showExportSuccess,
				   actions: {},
				   message: { Text("Your OPML file has been successfully exported.", comment: "Alert message: exported OPML file successfully.") })
			.alert(Text("Error", comment: "Alert title: Error"),
				   isPresented: $viewModel.showImportExportError,
				   actions: {},
				   message: { Text(viewModel.importExportError?.localizedDescription ?? "Import/Export Error") } )
		}.navigationViewStyle(.stack)
	}
}
