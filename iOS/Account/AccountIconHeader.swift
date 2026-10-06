//
//  AccountIconHeader.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 9/18/26.
//

import SwiftUI
import Account

/// The account icon shown above the first section of the account setup sheets.
struct AccountIconHeader: View {

	let accountType: AccountType

	private static let iconSize: CGFloat = 48
	private static let verticalPadding: CGFloat = 20

	var body: some View {
		Image(uiImage: Assets.accountImage(accountType))
			.resizable()
			.scaledToFit()
			.foregroundStyle(.primary)
			.frame(width: Self.iconSize, height: Self.iconSize)
			.frame(maxWidth: .infinity)
			.padding(.vertical, Self.verticalPadding)
	}
}
