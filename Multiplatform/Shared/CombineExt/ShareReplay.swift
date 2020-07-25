//
//  ShareReplay.swift
//  CombineExt
//
//  Created by Jasdev Singh on 13/04/2020.
//  Copyright © 2020 Combine Community. All rights reserved.
//

#if canImport(Combine)
import Combine

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public extension Publisher {
	/// A variation on [share()](https://developer.apple.com/documentation/combine/publisher/3204754-share)
	/// that allows for buffering and replaying a `replay` amount of value events to future subscribers.
	///
	/// - Parameter count: The number of value events to buffer in a first-in-first-out manner.
	/// - Returns: A publisher that replays the specified number of value events to future subscribers.
	func share(replay count: Int) -> Publishers.Autoconnect<Publishers.Multicast<Self, ReplaySubject<Output, Failure>>> {
		multicast { ReplaySubject(bufferSize: count) }
			.autoconnect()
	}
}
#endif
