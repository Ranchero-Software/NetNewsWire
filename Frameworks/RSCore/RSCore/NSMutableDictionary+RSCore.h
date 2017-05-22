//
//  NSMutableDictionary+RSCore.h
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;


@interface NSMutableDictionary (RSCore)


/*If obj or key are nil, does nothing. No exception thrown.*/

- (void)rs_safeSetObject:(id)obj forKey:(id)key;

- (void)rs_removeObjectsForKeys:(NSArray *)keys;


@end
