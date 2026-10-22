//
//  AccountSetupSheet.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 10/9/26.
//

import SwiftUI
import Account

/// The frame shared by the account setup sheets: a form titled with the account name and a Cancel button.
/// While `isWorking` is true, a progress indicator shows and the sheet can’t be canceled or swiped away.
struct AccountSetupSheet<Content: View>: View {

	let accountType: AccountType
	let isWorking: Bool
	let content: Content

	@Environment(\.dismiss) private var dismiss

	init(accountType: AccountType, isWorking: Bool = false, @ViewBuilder content: () -> Content) {
		self.accountType = accountType
		self.isWorking = isWorking
		self.content = content()
	}

	var body: some View {
		NavigationStack {
			Form {
				content
			}
			.navigationTitle(Text(verbatim: accountType.displayName))
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button(NSLocalizedString("Cancel", comment: "Cancel button"), role: .cancel) {
						dismiss()
					}
					.disabled(isWorking)
				}
				ToolbarItem(placement: .topBarTrailing) {
					if isWorking {
						ProgressView()
					}
				}
			}
			.interactiveDismissDisabled(isWorking)
		}
	}
}
