//
//  RefreshProgressView.swift
//  NetNewsWire
//
//  Created by Phil Viso on 7/2/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct RefreshProgressView: View {
	
	@EnvironmentObject private var refreshProgress: RefreshProgressModel

	@ViewBuilder var body: some View {
		switch refreshProgress.state {
		case .refreshProgress(let progress):
			ProgressView(value: progress)
				.frame(width: progressViewWidth())
		case .lastRefreshDateText(let text):
			Text(text)
				.lineLimit(1)
				.font(.caption)
				.foregroundColor(.secondary)
		case .none:
			EmptyView()
		}
	}
	
	// MARK -
	
	private func progressViewWidth() -> CGFloat {
		#if os(macOS)
		return 40.0
		#else
		return 100.0
		#endif
	}
	
}
