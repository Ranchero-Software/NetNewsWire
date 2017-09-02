//
//  NSString+RSCore.h
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;
@import CoreGraphics;


BOOL RSStringIsEmpty(NSString * _Nullable s); /*Yes if null, NSNull, or length < 1*/

BOOL RSEqualStrings(NSString * _Nullable s1, NSString * _Nullable s2); /*Equal if both are nil*/

NS_ASSUME_NONNULL_BEGIN

NSString *RSStringReplaceAll(NSString *stringToSearch, NSString *searchFor, NSString *replaceWith); /*Literal search*/

@interface NSString (RSCore)


/*The hashed data is a UTF-8 encoded version of the string.*/

- (NSData *)rs_md5HashData;
- (NSString *)rs_md5HashString;


/*Trims whitespace from leading and trailing ends. Collapses internal whitespace to single @" " character.
 Whitespace is space, tag, cr, and lf characters.*/

- (NSString *)rs_stringWithCollapsedWhitespace;

- (NSString *)rs_stringByTrimmingWhitespace;

- (BOOL)rs_stringMayBeURL;

- (NSString *)rs_normalizedURLString; //Change feed: to http:, etc.

/*0.0f to 1.0f for each.*/

typedef struct {
	CGFloat red;
	CGFloat green;
	CGFloat blue;
	CGFloat alpha;
} RSRGBAComponents;

/*red, green, blue components default to 1.0 if not specified.
 alpha defaults to 1.0 if not specified.*/

- (RSRGBAComponents)rs_rgbaComponents;


/*If string doesn't have the prefix or suffix, it returns self. If prefix or suffix is nil or empty, returns self. If self and prefix or suffix are equal, returns @"".*/

- (NSString *)rs_stringByStrippingPrefix:(NSString *)prefix caseSensitive:(BOOL)caseSensitive;
- (NSString *)rs_stringByStrippingSuffix:(NSString *)suffix caseSensitive:(BOOL)caseSensitive;

- (NSString *)rs_stringByStrippingHTML:(NSUInteger)maxCharacters;

/*Filename from path, file URL string, or external URL string.*/

- (NSString *)rs_filename;

- (BOOL)rs_caseInsensitiveContains:(NSString *)s;

- (NSString *)rs_stringByEscapingSpecialXMLCharacters;

+ (NSString *)rs_stringWithNumberOfTabs:(NSInteger)numberOfTabs;
- (NSString *)rs_stringByPrependingNumberOfTabs:(NSInteger)numberOfTabs;

// Remove leading http:// or https://

- (NSString *)rs_stringByStrippingHTTPOrHTTPSScheme;

@end

NS_ASSUME_NONNULL_END
