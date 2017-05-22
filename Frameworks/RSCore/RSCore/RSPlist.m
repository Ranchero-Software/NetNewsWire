//
//  RSPlist.m
//  RSCore
//
//  Created by Brent Simmons on 7/26/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

#import "RSPlist.h"

@implementation RSPlist

+ (BOOL)writePlist:(id)obj filePath:(NSString *)filePath error:(NSError **)error {
    
    NSData *propertyListData = [NSPropertyListSerialization dataWithPropertyList:obj format:NSPropertyListBinaryFormat_v1_0 options:0 error:error];
 
	static NSLock *lock = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		lock = [[NSLock alloc] init];
	});
	
	[lock lock];
    BOOL success = [propertyListData writeToFile:filePath options:NSDataWritingAtomic error:error];
	[lock unlock];
	
    if (!success) {
        if (*error) {
            NSLog(@"Error writing property list: %@", *error);
        }
        else {
            NSLog(@"Unknown error writing property list.");
        }
    }
    
    return success;
}


@end
