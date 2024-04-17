//
//  Database.swift
//  RSDatabase
//
//  Created by Brent Simmons on 12/15/19.
//  Copyright © 2019 Brent Simmons. All rights reserved.
//

import Foundation

public enum DatabaseError: Error, Sendable {
	case suspended // On iOS, to support background refreshing, a database may be suspended.
}
