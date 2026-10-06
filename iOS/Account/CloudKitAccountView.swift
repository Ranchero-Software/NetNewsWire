//
//  CloudKitAccountView.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 9/18/26.
//

import SwiftUI
import RSCore
import Account

/// Sheet for adding an iCloud account.
struct CloudKitAccountView: View {

	let didAddAccount: () -> Void

	@Environment(\.dismiss) private var dismiss
	@State private var iCloudDriveError: AddCloudKitAccountError?
	@State private var isShowingHelp = false

	var body: some View {
		NavigationStack {
			Form {
				Section {
					Button(NSLocalizedString("Use iCloud", comment: "Use iCloud button")) {
						addAccount()
					}
					.frame(maxWidth: .infinity)
				} header: {
					AccountIconHeader(accountType: .cloudKit)
				} footer: {
					AccountSheetFooter(text: NSLocalizedString("NetNewsWire will use your iCloud account to sync your subscriptions across your Mac and iOS devices.", comment: "iCloud"), linkTitle: CloudKitWebDocumentation.limitationsAndSolutionsText) {
						isShowingHelp = true
					}
				}
			}
			.navigationTitle(Text(verbatim: AccountType.cloudKit.displayName))
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button(NSLocalizedString("Cancel", comment: "Cancel button"), role: .cancel) {
						dismiss()
					}
				}
			}
			.alert(isPresented: isShowingiCloudDriveError, error: iCloudDriveError) { _ in
				Button(NSLocalizedString("Open Settings", comment: "Open Settings button")) {
					AddCloudKitAccountUtilities.openiCloudSettings()
				}
				Button(NSLocalizedString("Cancel", comment: "Cancel button"), role: .cancel) {
					iCloudDriveError = nil
				}
			} message: { error in
				Text(verbatim: error.recoverySuggestion ?? "")
			}
			.sheet(isPresented: $isShowingHelp) {
				SafariView(url: CloudKitWebDocumentation.limitationsAndSolutionsURL)
			}
		}
	}

	private var isShowingiCloudDriveError: Binding<Bool> {
		Binding {
			iCloudDriveError != nil
		} set: { isShowing in
			if !isShowing {
				iCloudDriveError = nil
			}
		}
	}

	private func addAccount() {
		guard AddCloudKitAccountUtilities.isiCloudDriveEnabled else {
			iCloudDriveError = .iCloudDriveMissing
			return
		}

		_ = AccountManager.shared.createAccount(type: .cloudKit)
		dismiss()
		didAddAccount()
	}
}
