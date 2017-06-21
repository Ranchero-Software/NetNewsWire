//
//  RSXMLInternal.h
//  RSXML
//
//  Created by Brent Simmons on 12/26/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

BOOL RSXMLIsEmpty(id _Nullable obj);
BOOL RSXMLStringIsEmpty(NSString * _Nullable s);


@interface NSString (RSXMLInternal)

- (NSString *)rsxml_md5HashString;

@end


@interface NSDictionary (RSXMLInternal)

- (nullable id)rsxml_objectForCaseInsensitiveKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END

