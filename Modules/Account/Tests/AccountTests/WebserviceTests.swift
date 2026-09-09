//
//  WebserviceTests.swift
//  AccountTests
//
//  Created by Brent Simmons on 9/7/26.
//

import Testing

/// Parent of every suite that registers canned responses with `TestingURLProtocol`.
///
/// They share one global response table, and Swift Testing runs tests in parallel by default,
/// so one suite's `reset()` can wipe another's registrations while its requests are in flight.
/// `.serialized` applies to nested suites, so nesting here keeps them from interleaving.
///
/// Any new suite that stubs webservice responses belongs here, whatever the account type.
@Suite(.serialized) struct WebserviceTests {
}
