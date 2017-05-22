//
//  NSFileManager+RSCore.h
//  RSCore
//
//  Created by Brent Simmons on 9/27/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface NSFileManager (RSCore)

- (BOOL)rs_copyFilesInFolder:(NSString *)source destination:(NSString *)destination error:(NSError * _Nullable * _Nullable)error;

- (NSArray<NSString *> *)rs_filenamesInFolder:(NSString *)folder;
- (NSArray<NSString *> *)rs_filepathsInFolder:(NSString *)folder;

- (BOOL)rs_fileIsFolder:(NSString *)f; // Returns NO if file doesn't exist.

@end

NS_ASSUME_NONNULL_END
