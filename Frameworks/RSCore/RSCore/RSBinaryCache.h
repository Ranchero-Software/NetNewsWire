//
//  RSBinaryCache.h
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

/*The folder this manages must already exist.
 Doesn't do any locking or queueing -- caller is responsible.*/


@interface RSBinaryCache : NSObject


- (instancetype)initWithFolder:(NSString *)folder;

- (NSString *)filePathForKey:(NSString *)key;

- (BOOL)setBinaryData:(NSData *)data key:(NSString *)key error:(NSError **)error;

- (NSData *)binaryDataForKey:(NSString *)key error:(NSError **)error;

- (BOOL)removeBinaryDataForKey:(NSString *)key error:(NSError **)error;

- (BOOL)binaryForKeyExists:(NSString *)key;

- (UInt64)lengthOfBinaryDataForKey:(NSString *)key error:(NSError **)error;

- (NSArray *)allKeys:(NSError **)error;


extern NSString *RSBinaryKey;
extern NSString *RSBinaryLength;

- (NSArray *)allObjects:(NSError **)error; /*NSDictionary objects with RSBinaryKey and RSBinaryLength. Key is filename.*/


@end
