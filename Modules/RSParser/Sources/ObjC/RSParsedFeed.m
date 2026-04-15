//
//  RSParsedFeed.m
//  RSParser
//
//  Created by Brent Simmons on 7/12/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

#import "RSParsedFeed.h"



@implementation RSParsedFeed

- (instancetype)initWithURLString:(NSString *)urlString title:(NSString *)title homepageURLString:(NSString *)homepageURLString iconURL:(NSString *)iconURL language:(NSString *)language articles:(NSSet *)articles {

	self = [super init];
	if (!self) {
		return nil;
	}

	_urlString = urlString;
	_title = title;
	_homepageURLString = homepageURLString;
	_iconURL = iconURL;
	_language = language;
	_articles = articles;

	return self;
}


@end
