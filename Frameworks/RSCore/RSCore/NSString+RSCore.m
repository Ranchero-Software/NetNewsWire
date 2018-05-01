//
//  NSString+RSCore.m
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

#import "NSString+RSCore.h"
#import "NSData+RSCore.h"


BOOL RSStringIsEmpty(NSString *s) {

	if (s == nil || (id)s == [NSNull null]) {
		return YES;
	}

	return s.length < 1;
}


BOOL RSEqualStrings(NSString *s1, NSString *s2) {

	return (s1 == nil && s2 == nil) || [s1 isEqualToString:s2];
}


NSString *RSStringReplaceAll(NSString *stringToSearch, NSString *searchFor, NSString *replaceWith) {

	if (RSStringIsEmpty(stringToSearch)) {
		return stringToSearch;
	}
	if (searchFor == nil || replaceWith == nil) {
		return stringToSearch;
	}

	NSMutableString *s = [stringToSearch mutableCopy];
	[s replaceOccurrencesOfString:searchFor withString:replaceWith options:NSLiteralSearch range:NSMakeRange(0, [s length])];

	return s;
}


@implementation NSString (RSCore)


- (NSData *)rs_md5HashData {

	NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding];
	return [data rs_md5Hash];
}


- (NSString *)rs_md5HashString {

	NSData *d = [self rs_md5HashData];
	return [d rs_hexadecimalString];
}


- (NSString *)rs_stringWithCollapsedWhitespace {

	NSMutableString *dest = [self mutableCopy];

	CFStringTrimWhitespace((__bridge CFMutableStringRef)dest);

	[dest replaceOccurrencesOfString:@"\t" withString:@" " options:NSLiteralSearch range:NSMakeRange(0, [dest length])];
	[dest replaceOccurrencesOfString:@"\r" withString:@" " options:NSLiteralSearch range:NSMakeRange(0, [dest length])];
	[dest replaceOccurrencesOfString:@"\n" withString:@" " options:NSLiteralSearch range:NSMakeRange(0, [dest length])];

	while ([dest rangeOfString:@"  " options:NSLiteralSearch].location != NSNotFound) {
		[dest replaceOccurrencesOfString:@"  " withString:@" " options:NSLiteralSearch range:NSMakeRange(0, [dest length])];
	}

	return dest;
}


- (NSString *)rs_stringByTrimmingWhitespace {

	return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}


- (BOOL)rs_stringContainsAnyCharacterFromSet:(NSCharacterSet *)characterSet {

	NSRange range = [self rangeOfCharacterFromSet:characterSet];
	return range.length > 0;
}

- (BOOL)rs_stringMayBeURL {

	NSString *s = [self rs_stringByTrimmingWhitespace];
	if (RSStringIsEmpty(s)) {
		return NO;
	}

	if (![s containsString:@"."]) {
		return NO;
	}

	if ([s rs_stringContainsAnyCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]) {
		return NO;
	}
	if ([s rs_stringContainsAnyCharacterFromSet:[NSCharacterSet controlCharacterSet]]) {
		return NO;
	}
	if ([s rs_stringContainsAnyCharacterFromSet:[NSCharacterSet illegalCharacterSet]]) {
		return NO;
	}

	return YES;
}


- (NSString *)rs_stringByReplacingPrefix:(NSString *)prefix withHTTPPrefix:(NSString *)httpPrefix {
	
	if ([self.lowercaseString hasPrefix:prefix]) {
		
		NSString *s = [self rs_stringByStrippingPrefix:prefix caseSensitive:NO];
		if (![s hasPrefix:@"//"]) {
			s = [NSString stringWithFormat:@"//%@", s];
		}
		s = [NSString stringWithFormat:@"%@%@", httpPrefix, s];
		
		return s;
	}
	return self;
}

/*
   given a URL that could be prefixed with 'feed:' or 'feeds:',
   convert it to a URL that begins with 'http:' or 'https:'
 
   Note: must handle edge case (like boingboing.net) where the feed URL is feed:http://boingboing.net/feed
 
   Strategy:
     1) note whether or not this is a feed: or feeds: or other prefix
     2) strip the feed: or feeds: prefix
     3) if the resulting string is not prefixed with http: or https:, then add http:// as a prefix
 
*/
- (NSString *)rs_normalizedURLString {
	
	NSString *s = [self rs_stringByTrimmingWhitespace];
	
	static NSString *feedPrefix = @"feed:";
	static NSString *feedsPrefix = @"feeds:";
	static NSString *httpPrefix = @"http";
	static NSString *httpsPrefix = @"https";
	Boolean wasFeeds = false;
 
    NSString *lowercaseS = [s lowercaseString];
    if ([lowercaseS hasPrefix:feedPrefix] || [lowercaseS hasPrefix:feedsPrefix]) {
        if ([lowercaseS hasPrefix:feedsPrefix]) {
            wasFeeds = true;
            s = [s rs_stringByStrippingPrefix:feedsPrefix caseSensitive:NO];
        } else {
            s = [s rs_stringByStrippingPrefix:feedPrefix caseSensitive:NO];
        }
    }
	
    lowercaseS = [s lowercaseString];
	if (![lowercaseS hasPrefix:httpPrefix]) {
		s = [NSString stringWithFormat: @"%@://%@", wasFeeds ? httpsPrefix : httpPrefix, s];
	}
	
	return s;
}


- (RSRGBAComponents)rs_rgbaComponents {

	RSRGBAComponents components = {0.0f, 0.0f, 0.0f, 1.0f};

	NSMutableString *s = [self mutableCopy];
	[s replaceOccurrencesOfString:@"#" withString:@"" options:NSLiteralSearch range:NSMakeRange(0, [s length])];
	CFStringTrimWhitespace((__bridge CFMutableStringRef)s);

	unsigned int red = 0, green = 0, blue = 0, alpha = 0;

	if ([s length] >= 2) {
		if ([[NSScanner scannerWithString:[s substringWithRange:NSMakeRange(0, 2)]] scanHexInt:&red]) {
			components.red = (CGFloat)red / 255.0f;
		}
	}

	if ([s length] >= 4) {
		if ([[NSScanner scannerWithString:[s substringWithRange:NSMakeRange(2, 2)]] scanHexInt:&green]) {
			components.green = (CGFloat)green / 255.0f;
		}
	}

	if ([s length] >= 6) {
		if ([[NSScanner scannerWithString:[s substringWithRange:NSMakeRange(4, 2)]] scanHexInt:&blue]) {
			components.blue = (CGFloat)blue / 255.0f;
		}
	}

	if ([s length] >= 8) {
		if ([[NSScanner scannerWithString:[s substringWithRange:NSMakeRange(6, 2)]] scanHexInt:&alpha]) {
			components.alpha = (CGFloat)alpha / 255.0f;
		}
	}

	return components;
}


- (NSString *)rs_stringByStrippingPrefix:(NSString *)prefix caseSensitive:(BOOL)caseSensitive {

	if (RSStringIsEmpty(prefix)) {
		return self;
	}

	if (!caseSensitive) {
		if (![self.lowercaseString hasPrefix:prefix.lowercaseString])
			return self;
	}
	else if (![self hasPrefix:prefix]) {
		return self;
	}

	if ([self isEqualToString:prefix]) {
		return @"";
	}
	if (!caseSensitive && [self caseInsensitiveCompare:prefix] == NSOrderedSame) {
		return @"";
	}

	return [self substringFromIndex:[prefix length]];
}


- (NSString *)rs_stringByStrippingSuffix:(NSString *)suffix caseSensitive:(BOOL)caseSensitive {

	if (RSStringIsEmpty(suffix)) {
		return self;
	}
	if (!caseSensitive) {
		if (![self.lowercaseString hasSuffix:suffix.lowercaseString]) {
			return self;
		}
	}
	else if (![self hasSuffix:suffix]) {
		return self;
	}

	if ([self isEqualToString:suffix]) {
		return @"";
	}
	if (!caseSensitive && [self caseInsensitiveCompare:suffix] == NSOrderedSame) {
		return @"";
	}

	return [self substringToIndex:self.length - suffix.length];
}

- (NSString *)rs_stringByStrippingHTML:(NSUInteger)maxCharacters {

	if (![self containsString:@"<"]) {

		if (maxCharacters > 0 && [self length] > maxCharacters) {
			return [self substringToIndex:maxCharacters];
		}

		return self;
	}

	NSMutableString *preflightedCopy = [self mutableCopy];
	[preflightedCopy replaceOccurrencesOfString:@"<blockquote>" withString:@" " options:NSCaseInsensitiveSearch range:NSMakeRange(0, preflightedCopy.length)];
	[preflightedCopy replaceOccurrencesOfString:@"</blockquote>" withString:@" " options:NSCaseInsensitiveSearch range:NSMakeRange(0, preflightedCopy.length)];
	[preflightedCopy replaceOccurrencesOfString:@"<p>" withString:@" " options:NSCaseInsensitiveSearch range:NSMakeRange(0, preflightedCopy.length)];
	[preflightedCopy replaceOccurrencesOfString:@"</p>" withString:@" " options:NSCaseInsensitiveSearch range:NSMakeRange(0, preflightedCopy.length)];
	[preflightedCopy replaceOccurrencesOfString:@"<div>" withString:@" " options:NSCaseInsensitiveSearch range:NSMakeRange(0, preflightedCopy.length)];
	[preflightedCopy replaceOccurrencesOfString:@"</div>" withString:@" " options:NSCaseInsensitiveSearch range:NSMakeRange(0, preflightedCopy.length)];

	CFMutableStringRef s = CFStringCreateMutable(kCFAllocatorDefault, (CFIndex)preflightedCopy.length);
	NSUInteger i = 0;
	NSUInteger level = 0;
	BOOL lastCharacterWasSpace = NO;
	unichar ch;
	const unichar chspace = ' ';
	NSUInteger charactersAdded = 0;

	for (i = 0; i < preflightedCopy.length; i++) {

		ch = [preflightedCopy characterAtIndex:i];

		if (ch == '<') {
			level++;
		}
		else if (ch == '>') {
			level--;
		}
		else if (level == 0) {

			if (ch == ' ' || ch == '\r' || ch == '\t' || ch == '\n') {
				if (lastCharacterWasSpace) {
					continue;
				}
				else {
					lastCharacterWasSpace = YES;
				}
				ch = chspace;
			}
			else {
				lastCharacterWasSpace = NO;
			}
			
			CFStringAppendCharacters(s, &ch, 1);
			if (maxCharacters > 0) {
				charactersAdded++;
				if (charactersAdded >= maxCharacters) {
					break;
				}
			}
		}
	}

	return (__bridge_transfer NSString *)s;
}

- (NSString *)rs_stringByConvertingToPlainText {

	if (![self containsString:@"<"]) {
		return self;
	}

	NSMutableString *preflightedCopy = [self mutableCopy];
	[preflightedCopy replaceOccurrencesOfString:@"<blockquote>" withString:@"\n\n" options:NSCaseInsensitiveSearch range:NSMakeRange(0, preflightedCopy.length)];
	[preflightedCopy replaceOccurrencesOfString:@"</blockquote>" withString:@"\n\n" options:NSCaseInsensitiveSearch range:NSMakeRange(0, preflightedCopy.length)];
	[preflightedCopy replaceOccurrencesOfString:@"<p>" withString:@"\n" options:NSCaseInsensitiveSearch range:NSMakeRange(0, preflightedCopy.length)];
	[preflightedCopy replaceOccurrencesOfString:@"</p>" withString:@"\n\n" options:NSCaseInsensitiveSearch range:NSMakeRange(0, preflightedCopy.length)];
	[preflightedCopy replaceOccurrencesOfString:@"<div>" withString:@"\n" options:NSCaseInsensitiveSearch range:NSMakeRange(0, preflightedCopy.length)];
	[preflightedCopy replaceOccurrencesOfString:@"</div>" withString:@"\n" options:NSCaseInsensitiveSearch range:NSMakeRange(0, preflightedCopy.length)];
	[preflightedCopy replaceOccurrencesOfString:@"<br>" withString:@"\n" options:NSCaseInsensitiveSearch range:NSMakeRange(0, preflightedCopy.length)];
	[preflightedCopy replaceOccurrencesOfString:@"<br />" withString:@"\n" options:NSCaseInsensitiveSearch range:NSMakeRange(0, preflightedCopy.length)];
	[preflightedCopy replaceOccurrencesOfString:@"<br/>" withString:@"\n" options:NSCaseInsensitiveSearch range:NSMakeRange(0, preflightedCopy.length)];
	[preflightedCopy replaceOccurrencesOfString:@"</li>" withString:@"\n" options:NSCaseInsensitiveSearch range:NSMakeRange(0, preflightedCopy.length)];

	CFMutableStringRef s = CFStringCreateMutable(kCFAllocatorDefault, (CFIndex)preflightedCopy.length);
	NSUInteger level = 0;

	for (NSUInteger i = 0; i < preflightedCopy.length; i++) {

		unichar ch = [preflightedCopy characterAtIndex:i];

		if (ch == '<') {
			level++;
		}
		else if (ch == '>') {
			level--;
		}
		else if (level == 0) {
			CFStringAppendCharacters(s, &ch, 1);
		}
	}

	NSMutableString *plainTextString = [(__bridge_transfer NSString *)s mutableCopy];
	while ([plainTextString rangeOfString:@"\n\n\n"].location != NSNotFound) {
		[plainTextString replaceOccurrencesOfString:@"\n\n\n" withString:@"\n\n" options:NSLiteralSearch range:NSMakeRange(0, plainTextString.length)];
	}

	return plainTextString;
}

- (NSString *)rs_filename {

	NSArray *components = [self componentsSeparatedByString:@"/"];
	NSString *filename = components.lastObject;
	if (RSStringIsEmpty(filename)) {
		if (components.count > 1) {
			filename = components[components.count - 2];
		}
	}

	return filename;
}


- (BOOL)rs_caseInsensitiveContains:(NSString *)s {
	
	NSRange range = [self rangeOfString:s options:NSCaseInsensitiveSearch];
	return range.location != NSNotFound;
}


- (NSString *)rs_stringByEscapingSpecialXMLCharacters {
	
	NSMutableString *s = [self mutableCopy];
	
	[s replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:NSLiteralSearch range:NSMakeRange(0, self.length)];
	[s replaceOccurrencesOfString:@"<" withString:@"&lt;" options:NSLiteralSearch range:NSMakeRange(0, s.length)];
	[s replaceOccurrencesOfString:@">" withString:@"&gt;" options:NSLiteralSearch range:NSMakeRange(0, s.length)];
	[s replaceOccurrencesOfString:@"&" withString:@"&amp;" options:NSLiteralSearch range:NSMakeRange(0, s.length)];
	
	return s;
}


+ (NSString *)rs_stringWithNumberOfTabs:(NSInteger)numberOfTabs {
	
	static dispatch_once_t onceToken;
	static NSMutableDictionary *cache = nil;
	
	dispatch_once(&onceToken, ^{
		cache = [NSMutableDictionary new];
	});
	
	NSString *cachedString = cache[@(numberOfTabs)];
	if (cachedString) {
		return cachedString;
	}
	
	NSMutableString *s = [@"" mutableCopy];
	for (NSInteger i = 0; i < numberOfTabs; i++) {
		[s appendString:@"\t"];
	}
	
	cache[@(numberOfTabs)] = s;
	return s;
}

- (NSString *)rs_stringByPrependingNumberOfTabs:(NSInteger)numberOfTabs {
	
	NSString *tabs = [NSString rs_stringWithNumberOfTabs:numberOfTabs];
	return [tabs stringByAppendingString:self];
}


- (NSString *)rs_stringByStrippingHTTPOrHTTPSScheme {

	NSString *s = [self rs_stringByStrippingPrefix:@"http://" caseSensitive:NO];
	s = [s rs_stringByStrippingPrefix:@"https://" caseSensitive:NO];
	return s;
}

+ (NSString *)rs_debugStringWithData:(NSData *)d {

	return [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
}

@end

