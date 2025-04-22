//
//  RSHTMLTag.h
//  RSParser
//
//  Created by Brent Simmons on 11/26/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

extern NSString *RSHTMLTagNameLink; // @"link"
extern NSString *RSHTMLTagNameMeta; // @"meta"

typedef NS_ENUM(NSInteger, RSHTMLTagType) {
	RSHTMLTagTypeLink,
	RSHTMLTagTypeMeta
};

@interface RSHTMLTag : NSObject

- (instancetype)initWithType:(RSHTMLTagType)type attributes:(NSDictionary *)attributes;

+ (RSHTMLTag *)linkTagWithAttributes:(NSDictionary *)attributes;
+ (RSHTMLTag *)metaTagWithAttributes:(NSDictionary *)attributes;

@property (nonatomic, readonly) RSHTMLTagType type;
@property (nonatomic, readonly) NSDictionary *attributes;

@end

NS_ASSUME_NONNULL_END
