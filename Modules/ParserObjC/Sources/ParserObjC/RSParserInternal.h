//
//  RSParserInternal.h
//  RSParser
//
//  Created by Brent Simmons on 12/26/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

BOOL RSParserObjectIsEmpty(id _Nullable obj);
BOOL RSParserStringIsEmpty(NSString * _Nullable s);


@interface NSDictionary (RSParserInternal)

- (nullable id)rsparser_objectForCaseInsensitiveKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END

