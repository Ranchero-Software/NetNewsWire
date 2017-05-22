//
//  RSPlatform.m
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

#import "RSPlatform.h"

NSString *RSDataFolder(NSString *appName) {

	NSString *dataFolder = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	if (appName == nil) {
		appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleExecutable"];
	}
	dataFolder = [dataFolder stringByAppendingPathComponent:appName];

	NSError *error = nil;

	if (![[NSFileManager defaultManager] createDirectoryAtPath:dataFolder withIntermediateDirectories:YES attributes:nil error:&error]) {
		NSLog(@"RSDataFolder error: %@", error);
		return nil;
	}

	return dataFolder;
}


NSString *RSDataFile(NSString *appName, NSString *fileName) {

	NSCParameterAssert(fileName != nil);

	NSString *dataFolder = RSDataFolder(appName);
	return [dataFolder stringByAppendingPathComponent:fileName];
}


NSString *RSDataSubfolder(NSString *appName, NSString *folderName) {

	NSCParameterAssert(folderName != nil);

	NSString *dataFolder = RSDataFile(appName, folderName);
	NSError *error = nil;

	if (![[NSFileManager defaultManager] createDirectoryAtPath:dataFolder withIntermediateDirectories:YES attributes:nil error:&error]) {
		NSLog(@"RSDataFolder error: %@", error);
		return nil;
	}

	return dataFolder;
}


NSString *RSDataSubfolderFile(NSString *appName, NSString *folderName, NSString *filename) {

	NSCParameterAssert(folderName != nil);
	NSCParameterAssert(filename != nil);

	NSString *dataFolder = RSDataSubfolder(appName, folderName);
	return [dataFolder stringByAppendingPathComponent:filename];
}
