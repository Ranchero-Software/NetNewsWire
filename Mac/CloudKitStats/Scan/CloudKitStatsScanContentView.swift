//
//  CloudKitStatsScanContentView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 3/24/26.
//

import AppKit

final class CloudKitStatsScanContentView: NSView {

	// MARK: - Status Records

	let statusRecordCountLabel = NSTextField(labelWithString: "0")
	let starredCountLabel = NSTextField(labelWithString: "0")
	let unreadCountLabel = NSTextField(labelWithString: "0")
	let readCountLabel = NSTextField(labelWithString: "0")

	// MARK: - Article Content Records

	let totalContentCountLabel = NSTextField(labelWithString: "0")
	let starredContentCountLabel = NSTextField(labelWithString: "0")
	let unreadContentCountLabel = NSTextField(labelWithString: "0")
	let readContentCountLabel = NSTextField(labelWithString: "0")

	// MARK: - Section containers (for alpha animation)

	let statusSectionView = NSView()
	let articleSectionView = NSView()

	init() {
		super.init(frame: .zero)
		translatesAutoresizingMaskIntoConstraints = false

		statusSectionView.translatesAutoresizingMaskIntoConstraints = false
		articleSectionView.translatesAutoresizingMaskIntoConstraints = false

		buildSectionRows(statusSectionView, rows: [
			.header(NSLocalizedString("Status Records", comment: "Status records section header")),
			.data(labelView: NSTextField(labelWithString: NSLocalizedString("Total", comment: "Total row label")), valueLabel: statusRecordCountLabel),
			.data(labelView: CloudKitStatsLayout.makeLabelWithIcon(NSLocalizedString("Starred", comment: "Starred row label"), symbolName: "star.fill", color: CloudKitStatsLayout.starColor), valueLabel: starredCountLabel),
			.data(labelView: CloudKitStatsLayout.makeLabelWithIcon(NSLocalizedString("Unread", comment: "Unread row label"), symbolName: "circle.fill", color: .controlAccentColor, iconOffset: 0.5), valueLabel: unreadCountLabel),
			.data(labelView: NSTextField(labelWithString: NSLocalizedString("Read", comment: "Read row label")), valueLabel: readCountLabel)
		])

		buildSectionRows(articleSectionView, rows: [
			.header(NSLocalizedString("Article Content Records", comment: "Article content records section header")),
			.data(labelView: NSTextField(labelWithString: NSLocalizedString("Total", comment: "Total row label")), valueLabel: totalContentCountLabel),
			.data(labelView: CloudKitStatsLayout.makeLabelWithIcon(NSLocalizedString("Starred", comment: "Starred row label"), symbolName: "star.fill", color: CloudKitStatsLayout.starColor), valueLabel: starredContentCountLabel),
			.data(labelView: CloudKitStatsLayout.makeLabelWithIcon(NSLocalizedString("Unread", comment: "Unread row label"), symbolName: "circle.fill", color: .controlAccentColor, iconOffset: 0.5), valueLabel: unreadContentCountLabel),
			.data(labelView: NSTextField(labelWithString: NSLocalizedString("Read", comment: "Read row label")), valueLabel: readContentCountLabel)
		])

		let divider = CloudKitStatsLayout.makeDivider()

		addSubview(statusSectionView)
		addSubview(divider)
		addSubview(articleSectionView)

		NSLayoutConstraint.activate([
			statusSectionView.topAnchor.constraint(equalTo: topAnchor),
			statusSectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
			statusSectionView.trailingAnchor.constraint(equalTo: trailingAnchor),

			divider.topAnchor.constraint(equalTo: statusSectionView.bottomAnchor, constant: CloudKitStatsLayout.sectionSpacing),
			divider.leadingAnchor.constraint(equalTo: leadingAnchor),
			divider.trailingAnchor.constraint(equalTo: trailingAnchor),

			articleSectionView.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: CloudKitStatsLayout.sectionSpacing),
			articleSectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
			articleSectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
			articleSectionView.bottomAnchor.constraint(equalTo: bottomAnchor)
		])
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

// MARK: - Private

private extension CloudKitStatsScanContentView {

	enum SectionRow {
		case header(String)
		case data(labelView: NSView, valueLabel: NSTextField)
	}

	func buildSectionRows(_ container: NSView, rows: [SectionRow]) {
		var constraints = [NSLayoutConstraint]()
		var previousAnchor = container.topAnchor
		var previousSpacing: CGFloat = 0
		var dataRowViews = [NSView]()

		for row in rows {
			switch row {
			case .header(let title):
				let headerLabel = NSTextField(labelWithString: title)
				headerLabel.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
				headerLabel.translatesAutoresizingMaskIntoConstraints = false

				container.addSubview(headerLabel)

				constraints.append(contentsOf: [
					headerLabel.topAnchor.constraint(equalTo: previousAnchor, constant: previousSpacing),
					headerLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor)
				])

				previousAnchor = headerLabel.bottomAnchor
				previousSpacing = CloudKitStatsLayout.rowSpacing

			case .data(let labelView, let valueLabel):
				labelView.translatesAutoresizingMaskIntoConstraints = false
				valueLabel.translatesAutoresizingMaskIntoConstraints = false
				CloudKitStatsLayout.configureValueLabel(valueLabel)

				container.addSubview(labelView)
				container.addSubview(valueLabel)

				// For icon rows, the labelView is a container — find the
				// text field inside it so baseline alignment is correct.
				let baselineView: NSView
				if let textField = labelView as? NSTextField {
					baselineView = textField
				} else if let textField = labelView.subviews.compactMap({ $0 as? NSTextField }).first {
					baselineView = textField
				} else {
					baselineView = labelView
				}

				constraints.append(contentsOf: [
					labelView.topAnchor.constraint(equalTo: previousAnchor, constant: previousSpacing),
					labelView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
					valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
					valueLabel.lastBaselineAnchor.constraint(equalTo: baselineView.lastBaselineAnchor)
				])

				dataRowViews.append(labelView)
				previousAnchor = labelView.bottomAnchor
				previousSpacing = CloudKitStatsLayout.rowSpacing
			}
		}

		// Make all data rows the same height (tallest wins).
		if let firstRow = dataRowViews.first {
			for row in dataRowViews.dropFirst() {
				constraints.append(row.heightAnchor.constraint(equalTo: firstRow.heightAnchor))
			}
		}

		constraints.append(previousAnchor.constraint(equalTo: container.bottomAnchor))
		NSLayoutConstraint.activate(constraints)
	}
}
