//
//  NSString+RSDatabase.h
//	RSDatabase
//
//  Created by Brent Simmons on 3/27/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface NSString (QSDatabase)


/*Returns @"(?, ?, ?)" -- where number of ? spots is specified by numberOfValues.
 numberOfValues should be greater than 0. Triggers an NSParameterAssert if not.*/

+ (nullable NSString *)rs_SQLValueListWithPlaceholders:(NSUInteger)numberOfValues;


/*Returns @"(someColumn, anotherColumm, thirdColumn)" -- using passed-in keys.
 It's essential that you trust keys. They must not be user input.
 Triggers an NSParameterAssert if keys are empty.*/

+ (NSString *)rs_SQLKeysListWithArray:(NSArray *)keys;


/*Returns @"key1=?, key2=?" using passed-in keys. Keys must be trusted.*/

+ (NSString *)rs_SQLKeyPlaceholderPairsWithKeys:(NSArray *)keys;


@end

NS_ASSUME_NONNULL_END
