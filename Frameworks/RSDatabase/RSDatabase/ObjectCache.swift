//
//  ObjectCache.swift
//  RSDatabase
//
//  Created by Brent Simmons on 7/29/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public final class ObjectCache<T> {

	private let keyPathForID: KeyPath<T,String>
	private var dictionary = [String: T]()

	public init(keyPathForID: KeyPath<T,String>) {

		self.keyPathForID = keyPathForID
	}

	public func addObjects(_ objects: [T]) {

		objects.forEach { addObject($0) }
	}

	public func add(_ object: T) {

		let identifier = identifierForObject(object)
		self[identifier] = object
	}

	public func removeObjects(_ objects: [T]) {

		objects.forEach { removeObject($0) }
	}

	public func removeObject(_ object: T) {

		let identifier = identifierForObject(object)
		self[identifier] = nil
	}

	public subscript(_ identifier: String) -> T? {
		get {
			return dictionary[identifier]
		}
		set {
			dictionary[identifier] = T
		}
	}
}

private extension ObjectCache {

	func identifierForObject(_ object: T) -> String {

		return object[keyPath: keyPathForID]
	}
}
