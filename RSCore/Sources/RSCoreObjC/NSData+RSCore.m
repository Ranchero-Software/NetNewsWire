//
//  NSData+RSCore.m
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

#import <CommonCrypto/CommonDigest.h>
#import "NSData+RSCore.h"


@implementation NSData (RSCore)


#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
- (NSData *)rs_md5Hash {

	unsigned char hash[CC_MD5_DIGEST_LENGTH];
	CC_MD5([self bytes], (CC_LONG)[self length], hash);

	return [NSData dataWithBytes:(const void *)hash length:CC_MD5_DIGEST_LENGTH];
}
#pragma GCC diagnostic pop

- (NSString *)rs_md5HashString {

	NSData *d = [self rs_md5Hash];
	return [d rs_hexadecimalString];
}

BOOL RSEqualBytes(const void *bytes1, const void *bytes2, size_t length) {

	return memcmp(bytes1, bytes2, length) == 0;
}


- (BOOL)rs_dataBeginsWithBytes:(const void *)bytes length:(size_t)numberOfBytes {

	if ([self length] < numberOfBytes) {
		return NO;
	}

	return RSEqualBytes([self bytes], bytes, numberOfBytes);
}


- (BOOL)rs_dataIsPNG {

	/* http://www.w3.org/TR/PNG/#5PNG-file-signature : "The first eight bytes of a PNG datastream always contain the following (decimal) values: 137 80 78 71 13 10 26 10" */

	static const Byte pngHeader[] = {137, 'P', 'N', 'G', 13, 10, 26, 10};
	return [self rs_dataBeginsWithBytes:pngHeader length:sizeof(pngHeader)];
}


- (BOOL)rs_dataIsGIF {

	/* http://www.onicos.com/staff/iz/formats/gif.html */

	static const Byte gifHeader1[] = {'G', 'I', 'F', '8', '7', 'a'};
	if ([self rs_dataBeginsWithBytes:gifHeader1 length:sizeof(gifHeader1)]) {
		return YES;
	}

	static const Byte gifHeader2[] = {'G', 'I', 'F', '8', '9', 'a'};
	return [self rs_dataBeginsWithBytes:gifHeader2 length:sizeof(gifHeader2)];
}


- (BOOL)rs_dataIsJPEG {

	const void *bytes = [self bytes];

	static const Byte jpegHeader1[] = {'J', 'F', 'I', 'F'};

	if (RSEqualBytes(bytes + 6, jpegHeader1, sizeof(jpegHeader1))) {
		return YES;
	}

	static const Byte jpegHeader2[] = {'E', 'x', 'i', 'f'};
	return RSEqualBytes(bytes + 6, jpegHeader2, sizeof(jpegHeader2));
}


- (BOOL)rs_dataIsImage {

	return [self rs_dataIsPNG] || [self rs_dataIsJPEG] || [self rs_dataIsGIF];
}


- (BOOL)rs_dataIsProbablyHTML {

	NSString *s = [self rs_noCopyString];
	if (!s) {
		return NO;
	}

	if (![s containsString:@">"] || ![s containsString:@">"]) {
		return NO;
	}

	for (NSString *oneString in @[@"html", @"body"]) {
		NSRange range = [s rangeOfString:oneString options:NSCaseInsensitiveSearch];
		if (range.location == NSNotFound) {
			return NO;
		}
	}

	return YES;
}


- (NSString *)rs_noCopyString {

	NSDictionary *options = @{NSStringEncodingDetectionSuggestedEncodingsKey : @[@(NSUTF8StringEncoding)]};
	BOOL usedLossyConversion = NO;
	NSStringEncoding encoding = [NSString stringEncodingForData:self encodingOptions:options convertedString:nil usedLossyConversion:&usedLossyConversion];
	if (encoding == 0) {
		return nil;
	}

	return [[NSString alloc] initWithBytesNoCopy:(void *)self.bytes length:self.length encoding:encoding freeWhenDone:NO];
}


NSString *RSHexadecimalStringWithBytes(const Byte *bytes, NSUInteger numberOfBytes) {

	if (numberOfBytes < 1) {
		return nil;
	}

	if (numberOfBytes == 16) {
		// Common case — MD5 hash, for example.
		return [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]];
	}
	
	NSMutableString *s = [[NSMutableString alloc] initWithString:@""];
	NSUInteger i = 0;

	for (i = 0; i < numberOfBytes; i++) {
		[s appendString:[NSString stringWithFormat:@"%02x", bytes[i]]];
	}

	return [s copy];
}


- (NSString *)rs_hexadecimalString {

	return RSHexadecimalStringWithBytes([self bytes], [self length]);
}


@end
