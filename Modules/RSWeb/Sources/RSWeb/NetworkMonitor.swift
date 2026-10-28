//
//  NetworkMonitor.swift
//  RSWeb
//
//  Created by Brent Simmons on 11/4/25.
//

import Foundation
import Network
import Synchronization

extension Notification.Name {
	/// Posted on the main thread when `isConnected` or `isConstrained` changes.
	public static let networkStatusDidChange = Notification.Name("NetworkStatusDidChange")
}

nonisolated public final class NetworkMonitor: Sendable {
	public static let shared = NetworkMonitor()

	private let monitor: NWPathMonitor
	private let queue = DispatchQueue(label: "RSWeb NetworkMonitor")

	private struct State: Sendable {
		var isConnected: Bool?
		var connectionType: NWInterface.InterfaceType?
		var isExpensive = false
		var isConstrained = false
	}

	private let state = Mutex(State())

	/// `true` until `NWPathMonitor` delivers its first path, so callers attempt
	/// network work rather than skip it on an answer we don't have yet.
	public var isConnected: Bool {
		state.withLock { $0.isConnected ?? true }
	}

	public var connectionType: NWInterface.InterfaceType? {
		state.withLock { $0.connectionType }
	}

	/// Is the connection expensive (cellular data with limited plan, for instance)
	public var isExpensive: Bool {
		state.withLock { $0.isExpensive }
	}

	/// Is the connection constrained (Low Data Mode enabled, for instance)
	public var isConstrained: Bool {
		state.withLock { $0.isConstrained }
	}

	@MainActor private var monitorIsActive = false

	private init() {
		monitor = NWPathMonitor()

		monitor.pathUpdateHandler = { [weak self] path in
			self?.updateStatus(with: path)
		}
	}

	@MainActor public func start() {
		guard !monitorIsActive else {
			assertionFailure("start called when already active")
			return
		}
		monitorIsActive = true
		monitor.start(queue: queue)
	}

	deinit {
		monitor.cancel()
	}

	private func updateStatus(with path: NWPath) {
		let statusDidChange = state.withLock { state in
			let isConnected = path.status == .satisfied
			let statusDidChange = isConnected != (state.isConnected ?? true) || path.isConstrained != state.isConstrained
			state.isConnected = isConnected
			state.connectionType = path.availableInterfaces.first?.type
			state.isExpensive = path.isExpensive
			state.isConstrained = path.isConstrained
			return statusDidChange
		}
		guard statusDidChange else {
			return
		}
		Task { @MainActor in
			NotificationCenter.default.post(name: .networkStatusDidChange, object: self)
		}
	}
}
