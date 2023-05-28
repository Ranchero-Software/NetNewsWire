//
//  AboutHTML.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 28/05/2023.
//  Copyright © 2023 Ranchero Software. All rights reserved.
//

import Html

@available(macOS 12, *)
struct AboutHTML: LoadableAboutData {

	private func stylesheet() -> StaticString {
	"""
		body {
			margin: 2em;
			color: #333333;
			background-color: white;
			line-height: 0.7em;
			font-family: -apple-system;
			text-align: center;
			font-size: 0.7em;
		}
		
		h3 { padding-top: 10px; padding-bottom: 10px; }
		@media (prefers-color-scheme: dark) {
			body {
			color: white;
			background-color: #333333;
			}
			
			a { color: rgba(94, 158, 244, 1); }
		}
	"""
	}
	
	private func document() -> Node {
		return Node.document(
			.html(
				.head(
					  .style(safe: stylesheet())
				),
				.body(
					Node.h3(.text(NSLocalizedString("label.text.primary-contributors", comment: "Primary Contributors"))),
					Node.fragment(about.PrimaryContributors.map { .p(.a(attributes: [.href($0.url ?? "")], "\($0.name)")) }),
					Node.h3(.text(NSLocalizedString("label.text.additional-contributors", comment: "Additional Contributors"))),
					Node.fragment(about.AdditionalContributors.map { .p(.a(attributes: [.href($0.url ?? "")], "\($0.name)")) })
				)
			)
		)
	}
	
	func renderedDocument() -> String {
		return render(document())
	}
}




