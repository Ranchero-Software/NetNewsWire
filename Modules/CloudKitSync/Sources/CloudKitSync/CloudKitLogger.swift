//
//  CloudKitLogger.swift
//  RSCore
//
//  Created by Brent Simmons on 10/2/25.
//

import Foundation
import os.log

public let cloudKitLogger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "CloudKit")
