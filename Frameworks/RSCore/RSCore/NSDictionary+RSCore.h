//
//  NSDictionary+RSCore.h
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

@interface NSDictionary (RSCore)

/*Keys that aren't strings are ignored. No coercion.*/

- (id)rs_objectForCaseInsensitiveKey:(NSString *)key;

- (BOOL)rs_boolForKey:(NSString *)key; /*NO if doesn't exist.*/

- (int64_t)rs_int64ForKey:(NSString *)key; /*0 if doesn't exist.*/

@end
