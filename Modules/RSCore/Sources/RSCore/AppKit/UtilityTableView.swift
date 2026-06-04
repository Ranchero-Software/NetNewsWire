//
//  UtilityTableView.swift
//  RSCore
//
//  Created by Brent Simmons on 6/1/26.
//

#if os(macOS)
import AppKit

/// NSTableView for utility windows that don't want their alternating-row
/// stripes to extend below the last data row.
public final class UtilityTableView: NSTableView {

	public override func drawBackground(inClipRect clipRect: NSRect) {
		super.drawBackground(inClipRect: clipRect)

		guard numberOfRows > 0 else {
			return
		}
		let belowLastRowY = rect(ofRow: numberOfRows - 1).maxY
		guard belowLastRowY < clipRect.maxY else {
			return
		}

		let coverRect = NSRect(
			x: clipRect.minX,
			y: belowLastRowY,
			width: clipRect.width,
			height: clipRect.maxY - belowLastRowY
		)
		(backgroundColor).setFill()
		coverRect.fill()
	}
}
#endif
