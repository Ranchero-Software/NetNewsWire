//
//  View+Extras.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 10/8/26.
//

import SwiftUI

extension View {

	/// Shows an Error alert with an OK button while `message` is non-nil. Dismissing the alert sets `message` to nil.
	func errorAlert(message: Binding<String?>) -> some View {
		let isPresented = Binding {
			message.wrappedValue != nil
		} set: { isShowing in
			if !isShowing {
				message.wrappedValue = nil
			}
		}

		return alert(NSLocalizedString("Error", comment: "Error"), isPresented: isPresented) {
			Button(NSLocalizedString("OK", comment: "OK button")) {
				message.wrappedValue = nil
			}
		} message: {
			Text(verbatim: message.wrappedValue ?? "")
		}
	}
}
