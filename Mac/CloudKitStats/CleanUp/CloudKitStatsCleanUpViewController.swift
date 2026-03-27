//
//  CloudKitStatsCleanUpViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 3/24/26.
//

import AppKit
import Account

final class CloudKitStatsCleanUpViewController: NSViewController {

	private let model: CloudKitStatsViewModel
	private let statusView = CloudKitStatsCleanUpStatusView()
	private let contentView = CloudKitStatsCleanUpContentView()

	init(model: CloudKitStatsViewModel) {
		self.model = model
		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) is not supported")
	}

	override func loadView() {
		let containerView = NSView()
		containerView.translatesAutoresizingMaskIntoConstraints = false

		statusView.cancelButton.target = nil
		statusView.cancelButton.action = #selector(CloudKitStatsViewController.cancelCleanUp(_:))

		contentView.refreshButton.target = nil
		contentView.refreshButton.action = #selector(CloudKitStatsViewController.refreshScan(_:))
		contentView.refreshScanButton.target = nil
		contentView.refreshScanButton.action = #selector(CloudKitStatsViewController.refreshScan(_:))
		contentView.returnToPreviousResultsButton.target = nil
		contentView.returnToPreviousResultsButton.action = #selector(CloudKitStatsViewController.returnToPreviousScanResults(_:))

		containerView.addSubview(statusView)
		containerView.addSubview(contentView)

		NSLayoutConstraint.activate([
			statusView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: CloudKitStatsLayout.sectionSpacing),
			statusView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
			statusView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

			contentView.topAnchor.constraint(equalTo: statusView.bottomAnchor, constant: CloudKitStatsLayout.sectionSpacing),
			contentView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
			contentView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
			contentView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
		])

		self.view = containerView
	}

	// MARK: - API

	func updateUI() {
		updateCleanUpView()
	}
}

// MARK: - Private

private extension CloudKitStatsCleanUpViewController {

	// MARK: - UI Update

	func updateCleanUpView() {
		if model.cleanUpStatus.cleanUpError != nil {
			updateCleanUpViewForError()
			return
		}

		let isCanceled = model.cleanUpStatus.isCanceled

		guard let progress = model.cleanUpStatus.progress else {
			return
		}

		contentView.errorTextField.isHidden = true
		contentView.refreshButton.isHidden = true
		statusView.isHidden = false

		let plan = model.cleanUpPlan

		// Progress bar: visible during cleaning, hidden when canceled, visible at 100% when completed
		if isCanceled {
			statusView.progressBar.isHidden = false
			statusView.cancelButton.isHidden = false
			statusView.cancelButton.isEnabled = false
			statusView.phaseTextField.isHidden = false
			statusView.phaseTextField.stringValue = NSLocalizedString("Cleanup canceled.", comment: "Cleanup status text when canceled")
		} else if model.cleanUpStatus.isCompleted {
			statusView.progressBar.isHidden = false
			statusView.progressBar.doubleValue = 1.0
			statusView.cancelButton.isEnabled = false
			statusView.phaseTextField.isHidden = false
			statusView.phaseTextField.stringValue = cleanUpPhaseText(progress.phase)
		} else {
			statusView.progressBar.isHidden = false
			statusView.cancelButton.isHidden = false
			statusView.cancelButton.isEnabled = true
			statusView.phaseTextField.isHidden = false
			statusView.phaseTextField.stringValue = cleanUpPhaseText(progress.phase)
			if plan.totalCount > 0 {
				statusView.progressBar.doubleValue = Double(progress.totalDeleted) / Double(plan.totalCount)
			} else {
				statusView.progressBar.doubleValue = 0
			}
		}

		updateStatRow(contentView.readContentDeletedRow, label: contentView.readContentDeletedLabel, value: progress.readContentDeleted, phase: progress.phase, showForPhase: .deletingReadContent)
		updateStatRow(contentView.unreadContentDeletedRow, label: contentView.unreadContentDeletedLabel, value: progress.unreadContentDeleted, phase: progress.phase, showForPhase: .deletingUnreadContent)

		contentView.navigationButtonGroup.isHidden = !(isCanceled || model.cleanUpStatus.isCompleted)
	}

	func updateCleanUpViewForError() {
		statusView.isHidden = true
		contentView.readContentDeletedRow.isHidden = true
		contentView.unreadContentDeletedRow.isHidden = true
		contentView.navigationButtonGroup.isHidden = true
		contentView.errorTextField.isHidden = false
		contentView.refreshButton.isHidden = false
		contentView.errorTextField.stringValue = NSLocalizedString("Cleanup failed to complete, but you may be able to clean up more if you wait a few minutes and try again.\n\nClick Refresh to see your updated stats.", comment: "Cleanup error message")
	}

	func updateStatRow(_ row: NSView, label: NSTextField, value: Int, phase: CloudKitCleanUpPhase, showForPhase: CloudKitCleanUpPhase) {
		row.isHidden = value == 0 && phase != showForPhase
		label.stringValue = CloudKitStatsLayout.formattedNumber(value)
	}

	func cleanUpPhaseText(_ phase: CloudKitCleanUpPhase) -> String {
		switch phase {
		case .deletingStaleStatus:
			return ""
		case .deletingReadContent:
			return NSLocalizedString("Deleting read content records…", comment: "Cleanup phase text")
		case .deletingUnreadContent:
			return NSLocalizedString("Deleting unread content records…", comment: "Cleanup phase text")
		case .completed:
			return NSLocalizedString("iCloud storage cleanup completed.", comment: "Cleanup phase text when completed")
		}
	}
}
