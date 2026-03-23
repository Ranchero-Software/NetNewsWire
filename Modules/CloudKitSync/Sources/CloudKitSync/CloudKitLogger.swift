//
//  CloudKitLogger.swift
//  RSCore
//
//  Created by Brent Simmons on 10/2/25.
//

import Foundation
import os

public let cloudKitLogger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "CloudKit")
