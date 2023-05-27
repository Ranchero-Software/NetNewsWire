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
	@Environment(\.scenePhase) var scenePhase
	@StateObject private var appDefaults = AppDefaults.shared
	@StateObject private var viewModel = SettingsViewModel()
	
	@Binding var isConfigureAppearanceShown: Bool
		
	var body: some View {
		NavigationView {
			List {
				// Device Permissions
				Section(header: Text("label.text.device-permissions", comment: "Device Permissions"),
						footer: Text("label.text.device-permissions-explainer", comment: "Configure NetNewsWire's access to Siri, background app refresh, mobile data, and more.")) {
					SettingsViewRows.openSystemSettings
				}
				
				// Account/Extensions/OPML Management
				Section(header: Text("label.text.accounts-and-extensions", comment: "Settings: Accounts & Extensions section header."),
						footer: Text("label.text.account-and-extensions-explainer", comment: "Add, delete, enable, or disable accounts and extensions.")) {
					SettingsViewRows.addAccount
					SettingsViewRows.manageExtensions
					SettingsViewRows.importOPML(showImportActionSheet: $viewModel.showImportActionSheet)
						.confirmationDialog(Text("actionsheet.title.choose-opml-destination", comment: "Choose an account to receive the imported feeds and folders"),
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
						.confirmationDialog(Text("actionsheet.title.choose-opml-export-account", comment: "Choose an account with the subscriptions to export"),
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
				Section(header: Text("label.text.appearance", comment: "Settings: Appearance section header."),
						footer: Text("label.text.appearance-explainer", comment: "Manage the look, feel, and behavior of NetNewsWire.")) {
					SettingsViewRows.configureAppearance($isConfigureAppearanceShown)
					if viewModel.notificationPermissions == .authorized {
						SettingsRow.configureNewArticleNotifications
					}
				}
				
				// Help
				Section {
					ForEach(0..<HelpSheet.allCases.count, id: \.self) { i in
						SettingsRow.showHelpSheet(sheet: HelpSheet.allCases[i], selectedSheet: $viewModel.helpSheet, $viewModel.showHelpSheet)
					}
					SettingsRow.aboutNetNewsWire
				}
			}
			.tint(Color(uiColor: AppAssets.primaryAccentColor))
			.listStyle(.insetGrouped)
			.navigationTitle(Text("navigation.title.settings", comment: "Settings"))
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .navigationBarLeading, content: {
					Button(action: { dismiss() }, label: { Text("button.title.done", comment: "Done") })
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
					Task { await MainActor.run { self.viewModel.notificationPermissions = settings.authorizationStatus }}
				}
			}
			.onChange(of: scenePhase, perform: { phase in
				if phase == .active {
					UNUserNotificationCenter.current().getNotificationSettings { settings in
						Task { await MainActor.run { self.viewModel.notificationPermissions = settings.authorizationStatus }}
					}
				}
			})
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
			.alert(Text("alert.title.opml.opml-import-success", comment: "Alert title: Imported Successfully"),
				   isPresented: $viewModel.showImportSuccess,
				   actions: {},
				   message: { Text("alert.message.opml-import-success.%@", comment: "Subscriptions have been imported to your “%@“ account.") })
			.alert(Text("alert.title.opml.opml-export-success", comment: "Alert title: Exported Successfully"),
				   isPresented: $viewModel.showExportSuccess,
				   actions: {},
				   message: { Text("alert.message.opml.opml-export-success", comment: "Your subscriptions have been exported successfully.") })
			.alert(Text("alert.title.error", comment: "Error"),
				   isPresented: $viewModel.showImportExportError,
				   actions: {},
				   message: { Text(verbatim: viewModel.importExportError?.localizedDescription ?? "") } )
		}.navigationViewStyle(.stack)
	}
}
