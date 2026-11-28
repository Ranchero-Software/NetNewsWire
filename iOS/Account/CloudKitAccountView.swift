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
	@State private var iCloudError: AddCloudKitAccountError?
	@State private var isCheckingiCloud = false
	@State private var isShowingHelp = false

	var body: some View {
		AccountSetupSheet(accountType: .cloudKit) {
			Section {
				Button(NSLocalizedString("Use iCloud", comment: "Use iCloud button")) {
					Task {
						await addAccount()
					}
				}
				.frame(maxWidth: .infinity)
				.disabled(isCheckingiCloud)
			} header: {
				AccountIconHeader(accountType: .cloudKit)
			} footer: {
				AccountSheetFooter(text: NSLocalizedString("NetNewsWire will use your iCloud account to sync your subscriptions across your Mac and iOS devices.", comment: "iCloud"), linkTitle: CloudKitWebDocumentation.limitationsAndSolutionsText) {
					isShowingHelp = true
				}
			}
		}
		.alert(isPresented: isShowingiCloudError, error: iCloudError) { _ in
			Button(NSLocalizedString("Open Settings", comment: "Open Settings button")) {
				AddCloudKitAccountUtilities.openiCloudSettings()
			}
			Button(NSLocalizedString("Cancel", comment: "Cancel button"), role: .cancel) {
				iCloudError = nil
			}
		} message: { error in
			Text(verbatim: error.recoverySuggestion ?? "")
		}
		.sheet(isPresented: $isShowingHelp) {
			SafariView(url: CloudKitWebDocumentation.limitationsAndSolutionsURL)
		}
	}

	private var isShowingiCloudError: Binding<Bool> {
		Binding {
			iCloudError != nil
		} set: { isShowing in
			if !isShowing {
				iCloudError = nil
			}
		}
	}

	private func addAccount() async {
		isCheckingiCloud = true
		defer {
			isCheckingiCloud = false
		}

		guard await AccountManager.shared.isiCloudAvailable() else {
			iCloudError = .iCloudUnavailable
			return
		}

		_ = AccountManager.shared.createAccount(type: .cloudKit)
		dismiss()
		didAddAccount()
	}
}
