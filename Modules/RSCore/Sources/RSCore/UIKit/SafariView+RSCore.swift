//
//  SafariView+RSCore.swift
//  RSCore
//
//  Created by Brent Simmons on 6/10/26.
//

#if os(iOS)

import SwiftUI
import SafariServices

public struct SafariView: UIViewControllerRepresentable {

	let url: URL

	public init(url: URL) {
		self.url = url
	}

	public func makeUIViewController(context: Context) -> SFSafariViewController {
		SFSafariViewController(url: url)
	}

	public func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
	}
}

#endif
