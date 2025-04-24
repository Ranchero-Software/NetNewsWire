//
//  RSHTMLTag.m
//  RSParser
//
//  Created by Brent Simmons on 11/26/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

#import "RSHTMLTag.h"

NSString *RSHTMLTagNameLink = @"link";
NSString *RSHTMLTagNameMeta = @"meta";

@implementation RSHTMLTag

- (instancetype)initWithType:(RSHTMLTagType)type attributes:(NSDictionary *)attributes {

	self = [super init];
	if (!self) {
		return nil;
	}

	_type = type;
	_attributes = attributes;
	
	return self;
}

+ (RSHTMLTag *)linkTagWithAttributes:(NSDictionary *)attributes {

	return [[self alloc] initWithType:RSHTMLTagTypeLink attributes:attributes];
}

+ (RSHTMLTag *)metaTagWithAttributes:(NSDictionary *)attributes {

	return [[self alloc] initWithType:RSHTMLTagTypeMeta attributes:attributes];
}

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p> type: %ld attributes: %@", NSStringFromClass([self class]), self, (long)self.type, self.attributes];
}

@end
