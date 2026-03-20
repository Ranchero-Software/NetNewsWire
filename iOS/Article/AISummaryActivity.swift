//
//  AISummaryActivity.swift
//  NetNewsWire-iOS
//
//  Created by Codex on 2026/3/20.
//

import UIKit

final class AISummaryActivity: UIActivity {

	private let handler: () -> Void

	init(handler: @escaping () -> Void) {
		self.handler = handler
		super.init()
	}

	override var activityTitle: String? {
		NSLocalizedString("AI Summary", comment: "AI Summary")
	}

	override var activityImage: UIImage? {
		UIImage(systemName: "sparkles", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .regular))
	}

	override var activityType: UIActivity.ActivityType? {
		UIActivity.ActivityType(rawValue: "com.ranchero.NetNewsWire.aiSummary")
	}

	override static var activityCategory: UIActivity.Category {
		.action
	}

	override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
		true
	}

	override func prepare(withActivityItems activityItems: [Any]) {
	}

	override func perform() {
		activityDidFinish(true)
		perform(#selector(runHandler), with: nil, afterDelay: 0.1)
	}

	@objc private func runHandler() {
		handler()
	}
}
