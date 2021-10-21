//
//  ShadowTableChanges.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 10/20/21.
//  Copyright © 2021 Ranchero Software. All rights reserved.
//

import Foundation

public struct ShadowTableChanges {
	
	public struct Move: Hashable {
		public var from: Int
		public var to: Int
		
		init(_ from: Int, _ to: Int) {
			self.from = from
			self.to = to
		}
	}
	
	public var section: Int
	public var deletes: Set<Int>?
	public var inserts: Set<Int>?
	public var moves: Set<Move>?
	public var reloads: Set<Int>?
	
	public var isEmpty: Bool {
		return (deletes?.isEmpty ?? true) && (inserts?.isEmpty ?? true) && (moves?.isEmpty ?? true) && (reloads?.isEmpty ?? true)
	}
	
	public var isOnlyReloads: Bool {
		return (deletes?.isEmpty ?? true) && (inserts?.isEmpty ?? true) && (moves?.isEmpty ?? true)
	}
	
	public var deleteIndexPaths: [IndexPath]? {
		guard let deletes = deletes else { return nil }
		return deletes.map { IndexPath(row: $0, section: section) }
	}
	
	public var insertIndexPaths: [IndexPath]? {
		guard let inserts = inserts else { return nil }
		return inserts.map { IndexPath(row: $0, section: section) }
	}
	
	public var moveIndexPaths: [(IndexPath, IndexPath)]? {
		guard let moves = moves else { return nil }
		return moves.map { (IndexPath(row: $0.from, section: section), IndexPath(row: $0.to, section: section)) }
	}
	
	public var reloadIndexPaths: [IndexPath]? {
		guard let reloads = reloads else { return nil }
		return reloads.map { IndexPath(row: $0, section: section) }
	}
	
	init(section: Int, deletes: Set<Int>? = nil, inserts: Set<Int>? = nil, moves: Set<Move>? = nil, reloads: Set<Int>? = nil) {
		self.section = section
		self.deletes = deletes
		self.inserts = inserts
		self.moves = moves
		self.reloads = reloads
	}
	
}
