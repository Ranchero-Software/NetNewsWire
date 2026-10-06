//
//  AccountSheetFooter.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 9/18/26.
//

import SwiftUI

/// Centered description text with a link button below it, used as the last section footer of the account setup sheets.
struct AccountSheetFooter: View {

	let text: String
	let linkTitle: String
	let linkAction: () -> Void

	private static let spacing: CGFloat = 16

	var body: some View {
		VStack(spacing: Self.spacing) {
			Text(text)
				.multilineTextAlignment(.center)
			Button(linkTitle, action: linkAction)
		}
		.frame(maxWidth: .infinity)
	}
}
