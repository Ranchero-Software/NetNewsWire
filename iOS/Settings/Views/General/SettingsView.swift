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
				Section(header: Text("DEVICE_PERMISSIONS_HEADER", tableName: "Settings"),
						footer: Text("DEVICE_PERMISSIONS_FOOTER", tableName: "Settings")) {
					SettingsViewRows.openSystemSettings
				}
				
				// Account/Extensions/OPML Management
				Section(header: Text("ACCOUNTS_EXTENSIONS_HEADER", tableName: "Settings"),
						footer: Text("ACCOUNTS_EXTENSIONS_FOOTER", tableName: "Settings")) {
					SettingsViewRows.addAccount
					SettingsViewRows.manageExtensions
					SettingsViewRows.importOPML(showImportActionSheet: $viewModel.showImportActionSheet)
						.confirmationDialog(Text("IMPORT_OPML_CONFIRMATION", tableName: "Settings"),
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
						.confirmationDialog(Text("EXPORT_OPML_CONFIRMATION", tableName: "Settings"),
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
				Section(header: Text("APPEARANCE_HEADER", tableName: "Settings"),
						footer: Text("APPEARANCE_FOOTER", tableName: "Settings")) {
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
			.navigationTitle(Text("SETTINGS_TITLE", tableName: "Settings"))
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .navigationBarLeading, content: {
					Button(action: { dismiss() }, label: { Text("DONE_BUTTON_TITLE", tableName: "Buttons") })
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
					viewModel.importAccount!.importOPML(url) { importResult in
						switch importResult {
						case .success(_):
							viewModel.showImportSuccess = true
						case .failure(let error):
							viewModel.importExportError = error
							viewModel.showImportExportError = true
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
			.alert(Text("IMPORT_OPML_SUCCESS_TITLE", tableName: "Settings"),
				   isPresented: $viewModel.showImportSuccess,
				   actions: {},
				   message: { Text("IMPORT_OPML_SUCCESS_MESSAGE \(viewModel.importAccount?.nameForDisplay ?? "")", tableName: "Settings") })
			.alert(Text("EXPORT_OPML_SUCCESS_TITLE", tableName: "Settings"),
				   isPresented: $viewModel.showExportSuccess,
				   actions: {},
				   message: { Text("EXPORT_OPML_SUCCESS_MESSAGE", tableName: "Settings") })
			.alert(Text("ERROR_TITLE", tableName: "Errors"),
				   isPresented: $viewModel.showImportExportError,
				   actions: {},
				   message: { Text(viewModel.importExportError?.localizedDescription ?? "Import/Export Error") } )
		}.navigationViewStyle(.stack)
	}
}
