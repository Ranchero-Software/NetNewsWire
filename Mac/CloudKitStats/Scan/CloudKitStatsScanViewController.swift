//
//  CloudKitStatsScanViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 3/24/26.
//

import AppKit
import CloudKit
import Account
import CloudKitSync

final class CloudKitStatsScanViewController: NSViewController {

	private let model: CloudKitStatsViewModel

	private let statusView = CloudKitStatsScanStatusView()
	private let contentView = CloudKitStatsScanContentView()

	private var hasShownErrorAlert = false

	// MARK: - Init

	init(model: CloudKitStatsViewModel) {
		self.model = model
		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) is not supported")
	}

	// MARK: - NSViewController

	override func loadView() {
		let containerView = NSView()
		containerView.translatesAutoresizingMaskIntoConstraints = false

		let topDivider = CloudKitStatsLayout.makeDivider()

		containerView.addSubview(statusView)
		containerView.addSubview(topDivider)
		containerView.addSubview(contentView)

		NSLayoutConstraint.activate([
			statusView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: CloudKitStatsLayout.sectionSpacing),
			statusView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
			statusView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

			topDivider.topAnchor.constraint(equalTo: statusView.bottomAnchor, constant: CloudKitStatsLayout.sectionSpacing),
			topDivider.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: -CloudKitStatsLayout.horizontalPadding),
			topDivider.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: CloudKitStatsLayout.horizontalPadding),

			contentView.topAnchor.constraint(equalTo: topDivider.bottomAnchor, constant: CloudKitStatsLayout.sectionSpacing),
			contentView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
			contentView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
			contentView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
		])

		self.view = containerView
	}

	// MARK: - API

	func updateUI() {
		NSAnimationContext.runAnimationGroup { context in
			context.duration = CloudKitStatsLayout.animationDuration
			context.allowsImplicitAnimation = true
			updateStatusBar()
			updateStatsValues()
		}
	}
}

// MARK: - Private

private extension CloudKitStatsScanViewController {

	// MARK: - UI Update

	func updateStatusBar() {
		switch model.fetchStatus {
		case .idle:
			break
		case .fetching:
			hasShownErrorAlert = false
			statusView.spinner.isHidden = false
			statusView.spinner.isIndeterminate = true
			statusView.spinner.style = .spinning
			statusView.spinner.startAnimation(nil)
			statusView.statusIcon.isHidden = true
			statusView.statusTextField.stringValue = NSLocalizedString("Scanning iCloud storage", comment: "Scan status text while fetching")
			statusView.actionButton.title = NSLocalizedString("Cancel", comment: "Cancel button")
			statusView.actionButton.keyEquivalent = "\u{1b}"
			statusView.actionButton.action = #selector(CloudKitStatsViewController.cancelScan(_:))
			statusView.statusTextLeadingToSpinner.isActive = true
			statusView.statusTextLeadingToContainer.isActive = false
		case .completed:
			statusView.spinner.isHidden = true
			statusView.spinner.stopAnimation(nil)
			statusView.statusIcon.isHidden = false
			statusView.statusTextField.stringValue = NSLocalizedString("Scan completed.", comment: "Scan status text when completed")
			statusView.actionButton.title = NSLocalizedString("Refresh", comment: "Refresh button")
			statusView.actionButton.keyEquivalent = ""
			statusView.actionButton.action = #selector(CloudKitStatsViewController.refreshScan(_:))
			statusView.statusTextLeadingToSpinner.isActive = true
			statusView.statusTextLeadingToContainer.isActive = false
		case .error:
			statusView.spinner.isHidden = true
			statusView.spinner.stopAnimation(nil)
			statusView.statusIcon.isHidden = true
			statusView.statusTextField.stringValue = NSLocalizedString("Scan failed. Numbers are incomplete.", comment: "Scan status text on error")
			statusView.actionButton.title = NSLocalizedString("Refresh", comment: "Refresh button")
			statusView.actionButton.keyEquivalent = ""
			statusView.actionButton.action = #selector(CloudKitStatsViewController.refreshScan(_:))
			statusView.statusTextLeadingToSpinner.isActive = false
			statusView.statusTextLeadingToContainer.isActive = true
			showErrorAlertIfNeeded()
		case .canceled:
			statusView.spinner.isHidden = true
			statusView.spinner.stopAnimation(nil)
			statusView.statusIcon.isHidden = true
			statusView.statusTextField.stringValue = NSLocalizedString("Canceled.", comment: "Scan status text when canceled")
			statusView.actionButton.title = NSLocalizedString("Refresh", comment: "Refresh button")
			statusView.actionButton.keyEquivalent = ""
			statusView.actionButton.action = #selector(CloudKitStatsViewController.refreshScan(_:))
			statusView.statusTextLeadingToSpinner.isActive = false
			statusView.statusTextLeadingToContainer.isActive = true
		}
	}

	func updateStatsValues() {
		let stats = model.stats
		contentView.statusRecordCountLabel.stringValue = CloudKitStatsLayout.formattedNumber(stats.statusCount)
		contentView.starredCountLabel.stringValue = CloudKitStatsLayout.formattedNumber(stats.starredStatusCount)
		contentView.unreadCountLabel.stringValue = CloudKitStatsLayout.formattedNumber(stats.unreadStatusCount)
		contentView.readCountLabel.stringValue = CloudKitStatsLayout.formattedNumber(stats.readStatusCount)
		contentView.totalContentCountLabel.stringValue = CloudKitStatsLayout.formattedNumber(stats.articleCount)
		contentView.starredContentCountLabel.stringValue = CloudKitStatsLayout.formattedNumber(stats.starredArticleCount)
		contentView.unreadContentCountLabel.stringValue = CloudKitStatsLayout.formattedNumber(stats.unreadArticleCount)
		contentView.readContentCountLabel.stringValue = CloudKitStatsLayout.formattedNumber(stats.readArticleCount)

		let isFetching = model.fetchStatus.isFetching
		let statusSectionDone = !isFetching || stats.articleCount > 0
		contentView.statusSectionView.animator().alphaValue = statusSectionDone ? 1.0 : CloudKitStatsLayout.fetchingAlpha
		contentView.articleSectionView.animator().alphaValue = isFetching ? CloudKitStatsLayout.fetchingAlpha : 1.0

		let syncUnreadContent = UserDefaults.standard.bool(forKey: Account.iCloudSyncArticleContentForUnreadArticlesKey)
		updateWarningColor(contentView.unreadContentCountLabel, count: syncUnreadContent ? 0 : stats.unreadArticleCount)
		updateWarningColor(contentView.readContentCountLabel, count: stats.readArticleCount)
	}

	func updateWarningColor(_ label: NSTextField, count: Int) {
		label.textColor = count > 0 ? CloudKitStatsLayout.warningColor : .labelColor
	}

	func showErrorAlertIfNeeded() {
		guard let fetchError = model.fetchStatus.fetchError, !hasShownErrorAlert else {
			return
		}

		hasShownErrorAlert = true
		let displayError: Error
		if fetchError is CKError {
			displayError = CloudKitError(fetchError)
		} else {
			displayError = fetchError
		}
		let alert = NSAlert()
		alert.alertStyle = .warning
		alert.messageText = NSLocalizedString("Couldn’t complete the iCloud scan because of an error:", comment: "Scan error alert title")
		alert.informativeText = displayError.localizedDescription
		alert.addButton(withTitle: NSLocalizedString("OK", comment: "OK button"))
		alert.runModal()
	}
}
