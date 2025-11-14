//
//  NetworkMonitor.swift
//  RSWeb
//
//  Created by Brent Simmons on 11/4/25.
//

import Foundation
import Network
import os

nonisolated public final class NetworkMonitor: Sendable {
	public static let shared = NetworkMonitor()

	private let monitor: NWPathMonitor
	private let queue = DispatchQueue(label: "RSWeb NetworkMonitor")

	private struct State: Sendable {
		var isConnected = false
		var connectionType: NWInterface.InterfaceType?
		var isExpensive = false
		var isConstrained = false
	}

	private let state = OSAllocatedUnfairLock<State>(initialState: State())

	public var isConnected: Bool {
		state.withLock { $0.isConnected }
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
		state.withLock { state in
			state.isConnected = path.status == .satisfied
			state.connectionType = path.availableInterfaces.first?.type
			state.isExpensive = path.isExpensive
			state.isConstrained = path.isConstrained
		}
	}
}
