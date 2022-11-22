//
//  ProgressBarView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 11/11/22.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//
// IndetermineProgressView inspired by https://daringsnowball.net/articles/indeterminate-linear-progress-view/

import SwiftUI
import Account

struct RefreshProgressView: View {
	
	static let width: CGFloat = 100
	static let height: CGFloat = 5
	
	@ObservedObject var refreshProgressModel: RefreshProgressModel
	@State private var offset: CGFloat = 0

	init(progressBarMode: RefreshProgressModel) {
		self.refreshProgressModel = progressBarMode
	}
	
	var body: some View {
		ZStack {
			if refreshProgressModel.isRefreshing {
				if refreshProgressModel.isIndeterminate {
					indeterminateProgressView
				} else {
					ProgressView(value: refreshProgressModel.progress)
						.progressViewStyle(LinearProgressViewStyle())
						.frame(width: Self.width, height: Self.height)
				}
			} else {
				Text(refreshProgressModel.label)
					.accessibilityLabel(refreshProgressModel.label)
					.font(.footnote)
					.foregroundColor(.secondary)
			}
		}
		.frame(width: 200, height: 44)
	}
	
	var indeterminateProgressView: some View {
		Rectangle()
			.foregroundColor(.gray.opacity(0.15))
			.overlay(
				Rectangle()
					.foregroundColor(Color.accentColor)
					.frame(width: Self.width * 0.26, height: Self.height)
					.clipShape(Capsule())
					.offset(x: -Self.width * 0.6, y: 0)
					.offset(x: Self.width * 1.2 * self.offset, y: 0)
					.animation(.default.repeatForever().speed(0.265), value: self.offset)
					.onAppear {
						withAnimation {
							self.offset = 1
						}
					}
					.onDisappear {
						self.offset = 0
					}
			)
			.clipShape(Capsule())
			.frame(width: Self.width, height: Self.height)
	}
	
}

class RefreshProgressModel: ObservableObject {
	
	@Published var isRefreshing = false
	@Published var isIndeterminate = false
	@Published var progress = 0.0
	@Published var label = String()
	
	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(progressDidChange(_:)), name: .AccountRefreshProgressDidChange, object: nil)
	}
	
	func update() {
		if !AccountManager.shared.combinedRefreshProgress.isComplete {
			progressChanged(animated: false)
		} else {
			updateRefreshLabel()
		}
	}
	
	@objc func progressDidChange(_ note: Notification) {
		progressChanged(animated: true)
	}
	
	deinit {
		NotificationCenter.default.removeObserver(self)
	}
	
}

private extension RefreshProgressModel {
	
	func progressChanged(animated: Bool) {
		let combinedRefreshProgress = AccountManager.shared.combinedRefreshProgress
		isIndeterminate = combinedRefreshProgress.isIndeterminate
		
		if combinedRefreshProgress.isComplete {
			isRefreshing = false
			progress = 1
			
			func completeLabel() {
				// Check that there are no pending downloads.
				if AccountManager.shared.combinedRefreshProgress.isComplete {
					updateRefreshLabel()
					progress = 0
				}
			}

			if animated {
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
					completeLabel()
				}
			} else {
				completeLabel()
			}
		} else {
			isRefreshing = true
			let percent = Double(combinedRefreshProgress.numberCompleted) / Double(combinedRefreshProgress.numberOfTasks)

			// Don't let the progress bar go backwards unless we need to go back more than 25%
			if percent > progress || (progress - percent) > 0.25 {
				progress = percent
			}
		}
	}

	func updateRefreshLabel() {
		if let accountLastArticleFetchEndTime = AccountManager.shared.lastArticleFetchEndTime {

			if Date() > accountLastArticleFetchEndTime.addingTimeInterval(60) {

				let relativeDateTimeFormatter = RelativeDateTimeFormatter()
				relativeDateTimeFormatter.dateTimeStyle = .named
				let refreshed = relativeDateTimeFormatter.localizedString(for: accountLastArticleFetchEndTime, relativeTo: Date())
				let localizedRefreshText = NSLocalizedString("Updated %@", comment: "Updated")
				let refreshText = NSString.localizedStringWithFormat(localizedRefreshText as NSString, refreshed) as String
				label = refreshText

			} else {
				label = NSLocalizedString("Updated Just Now", comment: "Updated Just Now")
			}

		} else {
			label = ""
		}
	}

	func scheduleUpdateRefreshLabel() {
		DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
			self?.updateRefreshLabel()
			self?.scheduleUpdateRefreshLabel()
		}
	}
	
}
