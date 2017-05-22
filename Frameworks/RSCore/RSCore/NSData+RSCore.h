//
//  NSData+RSCore.h
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;


BOOL RSEqualBytes(const void *bytes1, const void *bytes2, size_t length);

NSString *RSHexadecimalStringWithBytes(const unsigned char *bytes, NSUInteger numberOfBytes);


@interface NSData (RSCore)

- (NSData *)rs_md5Hash;
- (NSString *)rs_md5HashString;

- (BOOL)rs_dataIsPNG;
- (BOOL)rs_dataIsGIF;
- (BOOL)rs_dataIsJPEG;
- (BOOL)rs_dataIsImage;

- (BOOL)rs_dataIsProbablyHTML;

- (BOOL)rs_dataBeginsWithBytes:(const void *)bytes length:(size_t)numberOfBytes;

- (NSString *)rs_noCopyString; //This data object must out-live returned string. May return nil.

/*If bytes are deadbeef, then string is @"deadbeef". Returns nil for empty data.*/

- (NSString *)rs_hexadecimalString;

@end
