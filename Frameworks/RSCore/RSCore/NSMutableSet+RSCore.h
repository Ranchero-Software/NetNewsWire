//
//  NSMutableSet+RSCore.h
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;


@interface NSMutableSet (RSCore)


/*Does nothing if obj == nil. No exception thrown.*/

- (void)rs_safeAddObject:(id)obj;


@end
