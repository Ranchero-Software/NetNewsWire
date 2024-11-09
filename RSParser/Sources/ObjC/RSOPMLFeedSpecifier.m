//
//  RSOPMLFeedSpecifier.m
//  RSParser
//
//  Created by Brent Simmons on 2/28/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

#import "RSOPMLFeedSpecifier.h"
#import "RSParserInternal.h"



@implementation RSOPMLFeedSpecifier

- (instancetype)initWithTitle:(NSString *)title feedDescription:(NSString *)feedDescription homePageURL:(NSString *)homePageURL feedURL:(NSString *)feedURL {

	NSParameterAssert(!RSParserStringIsEmpty(feedURL));
	
	self = [super init];
	if (!self) {
		return nil;
	}

	if (RSParserStringIsEmpty(title)) {
		_title = nil;
	}
	else {
		_title = title;
	}

	if (RSParserStringIsEmpty(feedDescription)) {
		_feedDescription = nil;
	}
	else {
		_feedDescription = feedDescription;
	}

	if (RSParserStringIsEmpty(homePageURL)) {
		_homePageURL = nil;
	}
	else {
		_homePageURL = homePageURL;
	}

	_feedURL = feedURL;

	return self;
}

@end
