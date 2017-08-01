//
//  ObjectCache.swift
//  RSDatabase
//
//  Created by Brent Simmons on 7/29/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// Not thread-safe.

public final class ObjectCache<T> {

	private let keyPathForID: KeyPath<T,String>
	private var dictionary = [String: T]()

	public init(keyPathForID: KeyPath<T,String>) {

		self.keyPathForID = keyPathForID
	}

	public func addObjects(_ objects: [T]) {

		objects.forEach { add($0) }
	}

	public func addObjectsNotCached(_ objects: [T]) {

		objects.forEach { addIfNotCached($0) }
	}

	public func add(_ object: T) {

		let identifier = identifierForObject(object)
		self[identifier] = object
	}

	public func addIfNotCached(_ object: T) {

		let identifier = identifierForObject(object)
		if let _ = self[identifier] {
			return
		}
		self[identifier] = object
	}

	public func removeObjects(_ objects: [T]) {

		objects.forEach { removeObject($0) }
	}

	public func removeObject(_ object: T) {

		let identifier = identifierForObject(object)
		self[identifier] = nil
	}

	public func uniquedObjects(_ objects: [T]) -> [T] {

		// Return cached version of each object.
		// When an object is not already cached, cache it,
		// then consider that version the unique version.

		return objects.map { (object) -> T in

			let identifier = identifierForObject(object)
			if let cachedObject = self[identifier] {
				return cachedObject
			}
			add(object)
			return object
		}
	}

	public func objectWithIDIsCached(_ identifier: String) -> Bool {

		if let _ = self[identifier] {
			return true
		}
		return false
	}

	public subscript(_ identifier: String) -> T? {
		get {
			return dictionary[identifier]
		}
		set {
			dictionary[identifier] = newValue
		}
	}
}

private extension ObjectCache {

	func identifierForObject(_ object: T) -> String {

		return object[keyPath: keyPathForID]
	}
}
