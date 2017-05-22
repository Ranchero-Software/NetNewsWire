//
//  RSBinaryCache.m
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

#import "RSBinaryCache.h"


@interface RSBinaryCache ()

@property (nonatomic) NSString *folder;

@end


@implementation RSBinaryCache


#pragma mark - Init

- (instancetype)initWithFolder:(NSString *)folder {

	self = [super init];
	if (!self) {
		return nil;
	}

	_folder = folder;

	return self;
}


#pragma mark - API

- (NSString *)filePathForKey:(NSString *)key {

	return [self.folder stringByAppendingPathComponent:key];
}


- (BOOL)setBinaryData:(NSData *)data key:(NSString *)key error:(NSError **)error {

	NSString *f = [self filePathForKey:key];
	return [data writeToFile:f options:NSDataWritingAtomic error:error];
}


- (NSData *)binaryDataForKey:(NSString *)key error:(NSError **)error {

	NSString *f = [self filePathForKey:key];
	return [NSData dataWithContentsOfFile:f options:0 error:error];
}


- (BOOL)removeBinaryDataForKey:(NSString *)key error:(NSError **)error {

	NSString *f = [self filePathForKey:key];
	return [[NSFileManager defaultManager] removeItemAtPath:f error:error];
}


- (BOOL)binaryForKeyExists:(NSString *)key {

	NSString *f = [self filePathForKey:key];
	BOOL isDirectory = NO;
	return [[NSFileManager defaultManager] fileExistsAtPath:f isDirectory:&isDirectory];
}


- (UInt64)lengthOfBinaryDataForKey:(NSString *)key error:(NSError **)error {

	NSString *f = [self filePathForKey:key];
	NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:f error:error];
	return [fileAttributes fileSize];
}


- (NSArray *)allKeys:(NSError **)error {

	NSMutableArray *keys = [NSMutableArray new];

	NSArray *filenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.folder error:error];
	for (NSString *oneFilename in filenames) {

		if ([oneFilename hasPrefix:@"."]) {
			continue;
		}
		[keys addObject:oneFilename];
	}

	return [keys copy];
}


NSString *RSBinaryKey = @"key";
NSString *RSBinaryLength = @"length";

- (NSArray *)allObjects:(NSError **)error {

	NSMutableArray *objects = [NSMutableArray new];

	NSArray *filenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.folder error:error];
	if (!filenames && error) {
		return nil;
	}

	for (NSString *oneFilename in filenames) {

		if ([oneFilename hasPrefix:@"."]) {
			continue;
		}

		NSMutableDictionary *oneObject = [NSMutableDictionary new];
		oneObject[RSBinaryKey] = oneFilename;

		UInt64 length = [self lengthOfBinaryDataForKey:oneFilename error:nil];
		oneObject[RSBinaryLength] = @(length);

		[objects addObject:[oneObject copy]];
	}

	return [objects copy];
}

@end
