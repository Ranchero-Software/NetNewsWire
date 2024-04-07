/*
Copyright (c) 2014, Ashley Mills
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
*/

import SystemConfiguration
import Foundation

public enum ReachabilityError: Error {
	case failedToCreateWithHostname(String, Int32)
    case unableToGetFlags(Int32)
}

public class Reachability {

	/// Returns true if the internet is reachable.
	///
	/// Uses apple.com as an indicator for the internet at large,
	/// since it’s surely one of the easiest-to-reach domain names.
	/// Added 6 April 2024. Not part of Ashley Mills’s original code.
	public static var internetIsReachable: Bool {

		guard let reachability = try? Reachability(hostname: "apple.com") else {
			return false
		}
		return reachability.connection != .unavailable
	}

    public typealias NetworkReachable = (Reachability) -> ()
    public typealias NetworkUnreachable = (Reachability) -> ()

    @available(*, unavailable, renamed: "Connection")
    public enum NetworkStatus: CustomStringConvertible {
        case notReachable, reachableViaWiFi, reachableViaWWAN
        public var description: String {
            switch self {
            case .reachableViaWWAN: return "Cellular"
            case .reachableViaWiFi: return "WiFi"
            case .notReachable: return "No Connection"
            }
        }
    }

    public enum Connection: CustomStringConvertible {
        @available(*, deprecated, renamed: "unavailable")
        case none
        case unavailable, wifi, cellular
        public var description: String {
            switch self {
            case .cellular: return "Cellular"
            case .wifi: return "WiFi"
            case .unavailable: return "No Connection"
            case .none: return "unavailable"
            }
        }
    }

    /// Set to `false` to force Reachability.connection to .none when on cellular connection (default value `true`)
    public var allowsCellularConnection: Bool

    public var connection: Connection {
        if flags == nil {
            try? setReachabilityFlags()
        }
        
        switch flags?.connection {
        case .unavailable?, nil: return .unavailable
        case .none?: return .unavailable
        case .cellular?: return allowsCellularConnection ? .cellular : .unavailable
        case .wifi?: return .wifi
        }
    }

	fileprivate(set) var notifierRunning = false
	fileprivate let reachabilityRef: SCNetworkReachability
	fileprivate let reachabilitySerialQueue: DispatchQueue
	fileprivate(set) var flags: SCNetworkReachabilityFlags?

	required public init(reachabilityRef: SCNetworkReachability,
						 queueQoS: DispatchQoS = .default,
						 targetQueue: DispatchQueue? = nil) {
		self.allowsCellularConnection = true
		self.reachabilityRef = reachabilityRef
		self.reachabilitySerialQueue = DispatchQueue(label: "uk.co.ashleymills.reachability", qos: queueQoS, target: targetQueue)
	}

	public convenience init(hostname: String,
							queueQoS: DispatchQoS = .default,
							targetQueue: DispatchQueue? = nil) throws {
		guard let ref = SCNetworkReachabilityCreateWithName(nil, hostname) else {
			throw ReachabilityError.failedToCreateWithHostname(hostname, SCError())
		}
		self.init(reachabilityRef: ref, queueQoS: queueQoS, targetQueue: targetQueue)
	}
}

public extension Reachability {

    var description: String {
        return flags?.description ?? "unavailable flags"
    }
}

fileprivate extension Reachability {

    func setReachabilityFlags() throws {
        try reachabilitySerialQueue.sync { [unowned self] in
            var flags = SCNetworkReachabilityFlags()
            if !SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags) {
                throw ReachabilityError.unableToGetFlags(SCError())
            }
            
            self.flags = flags
        }
    }
}

extension SCNetworkReachabilityFlags {

    typealias Connection = Reachability.Connection

    var connection: Connection {
        guard isReachableFlagSet else { return .unavailable }

        // If we're reachable, but not on an iOS device (i.e. simulator), we must be on WiFi
        #if targetEnvironment(simulator)
        return .wifi
        #else
        var connection = Connection.unavailable

        if !isConnectionRequiredFlagSet {
            connection = .wifi
        }

        if isConnectionOnTrafficOrDemandFlagSet {
            if !isInterventionRequiredFlagSet {
                connection = .wifi
            }
        }

        if isOnWWANFlagSet {
            connection = .cellular
        }

        return connection
        #endif
    }

    var isOnWWANFlagSet: Bool {
        #if os(iOS)
        return contains(.isWWAN)
        #else
        return false
        #endif
    }
    var isReachableFlagSet: Bool {
        return contains(.reachable)
    }
    var isConnectionRequiredFlagSet: Bool {
        return contains(.connectionRequired)
    }
    var isInterventionRequiredFlagSet: Bool {
        return contains(.interventionRequired)
    }
    var isConnectionOnTrafficFlagSet: Bool {
        return contains(.connectionOnTraffic)
    }
    var isConnectionOnDemandFlagSet: Bool {
        return contains(.connectionOnDemand)
    }
    var isConnectionOnTrafficOrDemandFlagSet: Bool {
        return !intersection([.connectionOnTraffic, .connectionOnDemand]).isEmpty
    }
    var isTransientConnectionFlagSet: Bool {
        return contains(.transientConnection)
    }
    var isLocalAddressFlagSet: Bool {
        return contains(.isLocalAddress)
    }
    var isDirectFlagSet: Bool {
        return contains(.isDirect)
    }

    var description: String {
        let W = isOnWWANFlagSet ? "W" : "-"
        let R = isReachableFlagSet ? "R" : "-"
        let c = isConnectionRequiredFlagSet ? "c" : "-"
        let t = isTransientConnectionFlagSet ? "t" : "-"
        let i = isInterventionRequiredFlagSet ? "i" : "-"
        let C = isConnectionOnTrafficFlagSet ? "C" : "-"
        let D = isConnectionOnDemandFlagSet ? "D" : "-"
        let l = isLocalAddressFlagSet ? "l" : "-"
        let d = isDirectFlagSet ? "d" : "-"

        return "\(W)\(R) \(c)\(t)\(i)\(C)\(D)\(l)\(d)"
    }
}
