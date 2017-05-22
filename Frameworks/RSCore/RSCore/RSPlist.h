//
//  RSPlist.h
//  RSCore
//
//  Created by Brent Simmons on 7/26/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

@interface RSPlist : NSObject

// Writes using NSPropertyListBinaryFormat_v1_0.

+ (BOOL)writePlist:(id)obj filePath:(NSString *)filePath error:(NSError **)error;

@end
