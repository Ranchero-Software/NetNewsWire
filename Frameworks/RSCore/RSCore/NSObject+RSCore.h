//
//  NSObject+RSCore.h
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;


BOOL RSIsNil(id __nullable obj); // YES if nil or NSNull.

BOOL RSIsEmpty(id __nullable obj); /*YES if nil or NSNull -- or length or count < 1*/

BOOL RSEqualValues(id __nullable obj1, id __nullable obj2); // YES if both are nil or NSNull or isEqual: returns YES.

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (RSCore)


- (void)rs_takeValuesFromObject:(id)object propertyNames:(NSArray *)propertyNames;

- (NSDictionary *)rs_mergeValuesWithObjectReturningChanges:(id)object propertyNames:(NSArray <NSString *>*)propertyNames;

- (NSDictionary *)rs_dictionaryOfNonNilValues:(NSArray *)propertyNames;

@end

NS_ASSUME_NONNULL_END
