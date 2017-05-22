//
//  NSFileManager+RSCore.m
//  RSCore
//
//  Created by Brent Simmons on 9/27/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

#import "NSFileManager+RSCore.h"


static BOOL fileExists(NSString *f) {

	NSCParameterAssert(f);
	return f && [[NSFileManager defaultManager] fileExistsAtPath:f];
}

static BOOL fileIsFolder(NSString *f) {

	NSCParameterAssert(f);
	BOOL isFolder = NO;
	if (![[NSFileManager defaultManager] fileExistsAtPath:f isDirectory:&isFolder]) {
		return NO;
	}
	return isFolder;
}

static BOOL deleteFile(NSString *f, NSError **error) {

	NSCParameterAssert(f);
	NSCAssert(fileExists, f);

	if (!f || !fileExists(f)) {
		return NO;
	}

	return [[NSFileManager defaultManager] removeItemAtPath:f error:error];
}

static BOOL copyFile(NSString *source, NSString *dest, BOOL overwriteIfNecessary, NSError **error) {

	NSCParameterAssert(source);
	NSCParameterAssert(dest);
	NSCAssert(fileExists(source), nil);

	if (!dest || !source || !fileExists(source)) {
		return NO;
	}

	if (fileExists(dest)) {
		if (overwriteIfNecessary) {
			deleteFile(dest, error);
		}
		else {
			return NO;
		}
	}

	return [[NSFileManager defaultManager] copyItemAtPath:source toPath:dest error:error];
}

@implementation NSFileManager (RSCore)


- (BOOL)rs_copyFilesInFolder:(NSString *)source destination:(NSString *)destination error:(NSError **)error {

	NSAssert(fileIsFolder(source), nil);
	NSAssert(fileIsFolder(destination), nil);

	if (!fileIsFolder(source) || !fileIsFolder(destination)) {
		return NO;
	}

	NSArray *filenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:source error:error];
	if (!filenames) {
		return NO;
	}

	for (NSString *oneFilename in filenames) {

		if ([oneFilename hasPrefix:@"."]) {
			continue;
		}

		NSString *sourceFile = [source stringByAppendingPathComponent:oneFilename];
		NSString *destFile = [destination stringByAppendingPathComponent:oneFilename];

		if (!copyFile(sourceFile, destFile, YES, error)) {
			return NO;
		}
	}

	return YES;
}


- (NSArray *)rs_filenamesInFolder:(NSString *)folder {

	NSParameterAssert(folder);
	NSAssert(fileIsFolder(folder), nil);

	if (!folder || !fileIsFolder(folder)) {
		return @[];
	}

	return [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folder error:nil];
}


- (NSArray *)rs_filepathsInFolder:(NSString *)folder {

	NSArray *filenames = [self rs_filenamesInFolder:folder];
	if (!filenames) {
		return @[];
	}

	NSMutableArray *filepaths = [NSMutableArray new];
	for (NSString *oneFilename in filenames) {

		NSString *onePath = [oneFilename stringByAppendingPathComponent:oneFilename];
		[filepaths addObject:onePath];
	}

	return filepaths;
}


- (BOOL)rs_fileIsFolder:(NSString *)f {
	
	return fileIsFolder(f);
}

@end

