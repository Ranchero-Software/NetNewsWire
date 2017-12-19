//
//  NSString+RSParser.h
//  RSParser
//
//  Created by Brent Simmons on 9/25/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface NSString (RSParser)

- (NSString *)rsparser_stringByDecodingHTMLEntities;

- (NSString *)rsparser_md5Hash;

- (BOOL)rsparser_contains:(NSString *)s;

@end

NS_ASSUME_NONNULL_END
