//
//  Blocks.swift
//  RSCore
//
//  Created by Brent Simmons on 11/29/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public typealias VoidBlock = () -> Void
public typealias VoidCompletionBlock = VoidBlock

public typealias VoidResult = Result<Void, Error>
public typealias VoidResultCompletionBlock = (VoidResult) -> Void

public typealias ImageResultBlock = (RSImage?) -> Void
