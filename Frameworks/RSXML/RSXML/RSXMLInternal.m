//
//  RSXMLInternal.m
//  RSXML
//
//  Created by Brent Simmons on 12/26/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

#import <CommonCrypto/CommonDigest.h>
#import "RSXMLInternal.h"


static BOOL RSXMLIsNil(id obj) {
	
	return obj == nil || obj == [NSNull null];
}

BOOL RSXMLIsEmpty(id obj) {
	
	if (RSXMLIsNil(obj)) {
		return YES;
	}
	
	if ([obj respondsToSelector:@selector(count)]) {
		return [obj count] < 1;
	}
	
	if ([obj respondsToSelector:@selector(length)]) {
		return [obj length] < 1;
	}
	
	return NO; /*Shouldn't get here very often.*/
}

BOOL RSXMLStringIsEmpty(NSString *s) {
	
	return RSXMLIsNil(s) || s.length < 1;
}


@implementation NSString (RSXMLInternal)

- (NSData *)rsxml_md5Hash {
	
	NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding];
	unsigned char hash[CC_MD5_DIGEST_LENGTH];
	CC_MD5(data.bytes, (CC_LONG)data.length, hash);
	
	return [NSData dataWithBytes:(const void *)hash length:CC_MD5_DIGEST_LENGTH];
}

- (NSString *)rsxml_md5HashString {
	
	NSData *md5Data = [self rsxml_md5Hash];
	const Byte *bytes = md5Data.bytes;
	return [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]];
}

@end


@implementation NSDictionary (RSXMLInternal)


- (nullable id)rsxml_objectForCaseInsensitiveKey:(NSString *)key {
	
	id obj = self[key];
	if (obj) {
		return obj;
	}
	
	for (NSString *oneKey in self.allKeys) {
		
		if ([oneKey isKindOfClass:[NSString class]] && [key caseInsensitiveCompare:oneKey] == NSOrderedSame) {
			return self[oneKey];
		}
	}
	
	return nil;
}


@end
