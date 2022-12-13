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
	
	@StateObject private var appDefaults = AppDefaults.shared
	@StateObject private var viewModel = SettingsViewModel()
	
	@Binding var isConfigureAppearanceShown: Bool
		
	var body: some View {
		NavigationView {
			List {
				
				// Device Permissions
				Section(header: Text("Device Permissions"), footer: Text("Configure NetNewsWire's access to Siri, background app refresh, mobile data, and more.")) {
					SettingsViewRows.openSystemSettings
				}
				
				// Account/Extensions/OPML Management
				Section(header: Text("Accounts & Extensions"), footer: Text("Add, delete, enable, or disable accounts and extensions.")) {
					SettingsViewRows.addAccount
					SettingsViewRows.manageExtensions
					SettingsViewRows.importOPML(showImportActionSheet: $viewModel.showImportActionSheet)
						.confirmationDialog("Choose an account to receive the imported feeds and folders", isPresented: $viewModel.showImportActionSheet, titleVisibility: .visible) {
							ForEach(AccountManager.shared.sortedActiveAccounts, id: \.self) { account in
								Button(account.nameForDisplay) {
									viewModel.importAccount = account
									viewModel.showImportView = true
								}
							}
						}
					SettingsViewRows.exportOPML(showExportActionSheet: $viewModel.showExportActionSheet)
						.confirmationDialog("Choose an account with the subscriptions to export", isPresented: $viewModel.showExportActionSheet, titleVisibility: .visible) {
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
				Section(header: Text("Appearance"), footer: Text("Manage the look, feel, and behavior of NetNewsWire.")) {
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
			.navigationTitle(Text("Settings"))
			.navigationBarTitleDisplayMode(.inline)
			.sheet(isPresented: $viewModel.showAddAccountView) {
				AddAccountViewControllerRepresentable().edgesIgnoringSafeArea(.all)
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
			.alert("Imported Successfully", isPresented: $viewModel.showImportSuccess) {
				Button("Dismiss") {}
			} message: {
				Text("Import to your \(viewModel.importAccount?.nameForDisplay ?? "") account has completed.")
			}
			.alert("Exported Successfully", isPresented: $viewModel.showExportSuccess) {
				Button("Dismiss") {}
			} message: {
				Text("Your OPML file has been successfully exported.")
			}
			.alert("Error", isPresented: $viewModel.showImportExportError) {
				Button("Dismiss") {}
			} message: {
				Text(viewModel.importExportError?.localizedDescription ?? "Import/Export Error")
			}
		}.navigationViewStyle(.stack)
	}
}
