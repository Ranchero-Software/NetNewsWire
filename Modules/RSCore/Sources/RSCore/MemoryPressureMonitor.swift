//
//  MemoryPressureMonitor.swift
//  RSCore
//
//  Created by Brent Simmons on 3/7/26.
//

#if os(macOS)

import Foundation
import Dispatch

/// Observes GCD memory pressure events on macOS.
/// Posts `.lowMemory` on warn or critical.
public final class MemoryPressureMonitor: Sendable {
	public static let shared = MemoryPressureMonitor()

	private let source: DispatchSourceMemoryPressure

	init() {
		source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
		source.setEventHandler {
			postLowMemoryNotification()
		}
	}

	public func start() {
		source.activate()
	}
}

#endif
