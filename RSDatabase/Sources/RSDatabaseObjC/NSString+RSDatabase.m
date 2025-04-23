//
//  NSString+RSDatabase.m
//	RSDatabase
//
//  Created by Brent Simmons on 3/27/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

#import "NSString+RSDatabase.h"


@implementation NSString (RSDatabase)


+ (NSString *)rs_SQLValueListWithPlaceholders:(NSUInteger)numberOfValues {

	// @"(?, ?, ?)"

	NSParameterAssert(numberOfValues > 0);
	if (numberOfValues < 1) {
		return nil;
	}

	static NSMutableDictionary *cache = nil;
	static dispatch_once_t onceToken;
	static NSLock *lock = nil;
	dispatch_once(&onceToken, ^{
		lock = [[NSLock alloc] init];
		cache = [NSMutableDictionary new];
	});

	[lock lock];
	NSNumber *cacheKey = @(numberOfValues);
	NSString *cachedString = cache[cacheKey];
	if (cachedString) {
		[lock unlock];
		return cachedString;
	}

	NSMutableString *s = [[NSMutableString alloc] initWithString:@"("];
	NSUInteger i = 0;

	for (i = 0; i < numberOfValues; i++) {

		[s appendString:@"?"];
		BOOL isLast = (i == (numberOfValues - 1));
		if (!isLast) {
			[s appendString:@", "];
		}
	}

	[s appendString:@")"];
	
	cache[cacheKey] = s;
	[lock unlock];

	return s;
}


+ (NSString *)rs_SQLKeysListWithArray:(NSArray *)keys {

	NSParameterAssert(keys.count > 0);

	static NSMutableDictionary *cache = nil;
	static dispatch_once_t onceToken;
	static NSLock *lock = nil;
	dispatch_once(&onceToken, ^{
		lock = [[NSLock alloc] init];
		cache = [NSMutableDictionary new];
	});

	[lock lock];
	NSArray *cacheKey = keys;
	NSString *cachedString = cache[cacheKey];
	if (cachedString) {
		[lock unlock];
		return cachedString;
	}
	
	NSString *s = [NSString stringWithFormat:@"(%@)", [keys componentsJoinedByString:@", "]];

	cache[cacheKey] = s;
	[lock unlock];

	return s;
}


+ (NSString *)rs_SQLKeyPlaceholderPairsWithKeys:(NSArray *)keys {

	// key1=?, key2=?

	NSParameterAssert(keys.count > 0);
	
	static NSMutableDictionary *cache = nil;
	static dispatch_once_t onceToken;
	static NSLock *lock = nil;
	dispatch_once(&onceToken, ^{
		lock = [[NSLock alloc] init];
		cache = [NSMutableDictionary new];
	});

	[lock lock];
	NSArray *cacheKey = keys;
	NSString *cachedString = cache[cacheKey];
	if (cachedString) {
		[lock unlock];
		return cachedString;
	}
	
	NSMutableString *s = [NSMutableString stringWithString:@""];

	NSUInteger i = 0;
	NSUInteger numberOfKeys = [keys count];

	for (i = 0; i < numberOfKeys; i++) {

		NSString *oneKey = keys[i];
		[s appendString:oneKey];
		[s appendString:@"=?"];
		BOOL isLast = (i == (numberOfKeys - 1));
		if (!isLast) {
			[s appendString:@", "];
		}
	}

	cache[cacheKey] = s;
	[lock unlock];

	return s;
}


@end
