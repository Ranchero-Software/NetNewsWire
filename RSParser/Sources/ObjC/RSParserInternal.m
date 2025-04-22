//
//  RSParserInternal.m
//  RSParser
//
//  Created by Brent Simmons on 12/26/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//


#import "RSParserInternal.h"
#import <CommonCrypto/CommonDigest.h>


static BOOL RSParserIsNil(id obj) {
	
	return obj == nil || obj == [NSNull null];
}

BOOL RSParserObjectIsEmpty(id obj) {
	
	if (RSParserIsNil(obj)) {
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

BOOL RSParserStringIsEmpty(NSString *s) {
	
	return RSParserIsNil(s) || s.length < 1;
}


@implementation NSDictionary (RSParserInternal)

- (nullable id)rsparser_objectForCaseInsensitiveKey:(NSString *)key {
	
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
