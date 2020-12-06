//
//  TimelineTableRowView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/31/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import AppKit

class TimelineTableRowView : NSTableRowView {

	private var separator: NSView?
	
	override var isOpaque: Bool {
		return true
	}

	override var isEmphasized: Bool {
		didSet {
			cellView?.isEmphasized = isEmphasized
		}
	}
	
	override var isSelected: Bool {
		didSet {
			cellView?.isSelected = isSelected
			separator?.isHidden = isSelected
		}
	}
	
	init() {
		super.init(frame: NSRect.zero)
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}
	
	private var cellView: TimelineTableCellView? {
		for oneSubview in subviews {
			if let foundView = oneSubview as? TimelineTableCellView {
				return foundView
			}
		}
		return nil
	}

	override func viewDidMoveToSuperview() {
		if AppDefaults.shared.timelineShowsSeparators {
			addSeparatorView()
		}
	}
	
	private func addSeparatorView() {
		guard let cellView = cellView, separator == nil else { return }
		separator = NSView()
		separator!.translatesAutoresizingMaskIntoConstraints = false
		separator!.wantsLayer = true
		separator!.layer?.backgroundColor = AppAssets.timelineSeparatorColor.cgColor
		addSubview(separator!)
		if #available(macOS 11.0, *) {
			NSLayoutConstraint.activate([
				separator!.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 20),
				separator!.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
				separator!.heightAnchor.constraint(equalToConstant: 1),
				separator!.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0)
			])
		} else {
			NSLayoutConstraint.activate([
				separator!.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 34),
				separator!.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -28),
				separator!.heightAnchor.constraint(equalToConstant: 1),
				separator!.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0)
			])
		}
	}
	
}
