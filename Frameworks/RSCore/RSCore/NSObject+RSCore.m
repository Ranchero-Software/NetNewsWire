//
//  NSObject+RSCore.m
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

#import "NSObject+RSCore.h"


BOOL RSIsNil(id obj) {

	return obj == nil || obj == [NSNull null];
}

BOOL RSIsEmpty(id obj) {

	if (RSIsNil(obj)) {
		return YES;
	}

	if ([obj respondsToSelector:@selector(count)]) {
		return [obj count] < 1;
	}

	if ([obj respondsToSelector:@selector(length)]) {
		return [obj length] < 1;
	}

	return NO; /*Shouldn't get here very often.*/
}


BOOL RSEqualValues(id obj1, id obj2) {

	BOOL obj1IsNil = RSIsNil(obj1);
	BOOL obj2IsNil = RSIsNil(obj2);

	if (obj1IsNil && obj2IsNil) {
		return YES;
	}
	if (obj1IsNil != obj2IsNil) {
		return NO;
	}

	return [obj1 isEqual:obj2];
}


@implementation NSObject (RSCore)

- (void)rs_takeValuesFromObject:(id)object propertyNames:(NSArray *)propertyNames {

	for (NSString *onePropertyName in propertyNames) {

		id oneValue = [object valueForKey:onePropertyName];
		if (oneValue == (id)[NSNull null]) {
			[self setValue:nil forKey:onePropertyName];
		}
		else {
			[self setValue:oneValue forKey:onePropertyName];
		}
	}
}


- (NSDictionary *)rs_mergeValuesWithObjectReturningChanges:(id)object propertyNames:(NSArray *)propertyNames {

	NSMutableDictionary *changes = [NSMutableDictionary new];

	for (NSString *onePropertyName in propertyNames) {

		id oneLocalValue = [self valueForKey:onePropertyName];
		id oneRemoteValue = [object valueForKey:onePropertyName];

		if (RSEqualValues(oneLocalValue, oneRemoteValue)) {
			continue;
		}

		[self setValue:oneRemoteValue forKey:onePropertyName];
		changes[onePropertyName] = oneRemoteValue;
	}

	return [changes copy];
}


- (NSDictionary *)rs_dictionaryOfNonNilValues:(NSArray *)propertyNames {

	NSMutableDictionary *d = [NSMutableDictionary new];

	for (NSString *onePropertyName in propertyNames) {

		id oneValue = [self valueForKey:onePropertyName];
		if (RSIsNil(oneValue)) {
			continue;
		}

		d[onePropertyName] = oneValue;
	}

	return [d copy];
}

@end

