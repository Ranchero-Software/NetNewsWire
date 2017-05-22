//
//  NSArray+RSCore.h
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;
#import <RSCore/RSBlocks.h>


BOOL RSEqualArrays(NSArray *array1, NSArray *array2); /*Yes if both nil, identical, or equal*/


@interface NSArray (RSCore)


/*Returns nil if out of bounds instead of throwing an exception.*/

- (id)rs_safeObjectAtIndex:(NSUInteger)anIndex;

/*Does valueForKey:key. When value isEqual, returns YES.*/

- (id)rs_firstObjectWhereValueForKey:(NSString *)key equalsValue:(id)value;

- (id)rs_firstObjectPassingTest:(RSTestBlock)testBlock;


typedef id (^RSMapBlock)(id obj);

- (NSArray *)rs_map:(RSMapBlock)mapBlock;


typedef BOOL (^RSFilterBlock)(id obj);

- (NSArray *)rs_filter:(RSFilterBlock)filterBlock;

	
- (NSArray *)rs_arrayWithCopyOfEachObject;


/*Does [valueForKey:key] on each object and uses that as the key in the dictionary.*/

- (NSDictionary *)rs_dictionaryUsingKey:(id)key;


@end
