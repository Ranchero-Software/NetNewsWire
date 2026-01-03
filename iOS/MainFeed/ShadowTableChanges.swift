//
//  ShadowTableChanges.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 10/20/21.
//  Copyright © 2021 Ranchero Software. All rights reserved.
//

import Foundation

struct ShadowTableChanges {

	struct Move: Hashable {
		var from: Int
		var to: Int

		init(_ from: Int, _ to: Int) {
			self.from = from
			self.to = to
		}
	}

	struct RowChanges {

		var section: Int
		var deletes: Set<Int>?
		var inserts: Set<Int>?
		var reloads: Set<Int>?
		var moves: Set<ShadowTableChanges.Move>?

		var isEmpty: Bool {
			return (deletes?.isEmpty ?? true) && (inserts?.isEmpty ?? true) && (moves?.isEmpty ?? true)
		}

		var deleteIndexPaths: [IndexPath]? {
			guard let deletes = deletes else { return nil }
			return deletes.map { IndexPath(row: $0, section: section) }
		}

		var insertIndexPaths: [IndexPath]? {
			guard let inserts = inserts else { return nil }
			return inserts.map { IndexPath(row: $0, section: section) }
		}

		var reloadIndexPaths: [IndexPath]? {
			guard let reloads = reloads else { return nil }
			return reloads.map { IndexPath(row: $0, section: section) }
		}

		var moveIndexPaths: [(IndexPath, IndexPath)]? {
			guard let moves = moves else { return nil }
			return moves.map { (IndexPath(row: $0.from, section: section), IndexPath(row: $0.to, section: section)) }
		}

		init(section: Int, deletes: Set<Int>?, inserts: Set<Int>?, reloads: Set<Int>?, moves: Set<Move>?) {
			self.section = section
			self.deletes = deletes
			self.inserts = inserts
			self.reloads = reloads
			self.moves = moves
		}
	}

	var deletes: Set<Int>?
	var inserts: Set<Int>?
	var moves: Set<Move>?
	var rowChanges: [RowChanges]?

}
