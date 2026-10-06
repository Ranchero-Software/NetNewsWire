//
//  DinosaurRowView.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 10/06/2026.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import SwiftUI

struct DinosaurRowView: View {

	// MARK: Variables
	var dinosaur: DinosaurRow

	var body: some View {
		VStack(alignment: .leading) {
			HStack(alignment: .top) {
				if let img = IconImageCache.shared.imageFor(dinosaur.feed.sidebarItemID!) {
					IconImageView(icon: img)
				} else if let img = dinosaur.feed.smallIcon {
					IconImageView(icon: img)
				}
				VStack(alignment: .leading) {
					Text(verbatim: dinosaur.feedName)
						.font(.headline)
					Text(verbatim: dinosaur.feedURL)
						.font(.caption)
						.monospaced()
					LabeledContent {
						Text(verbatim: dinosaur.accountName)
					} label: {
						Text("Account", comment: "Account")
					}
					.font(.caption)
					if let lastArticleDate = dinosaur.lastArticleDate {
						LabeledContent {
							Text(verbatim: lastArticleDate.formatted(date: .abbreviated, time: .omitted))
						} label: {
							Text("Last Article", comment: "Last Article Date")
						}
						.font(.caption)
					}
					if let lastResponseCode = dinosaur.lastResponseCode {
						LabeledContent {
							Text(verbatim: lastResponseCode.formatted())
						} label: {
							Text("Last Response", comment: "Last HTTP Response")
						}
						.font(.caption)
					}
				}
			}

		}
	}
}
