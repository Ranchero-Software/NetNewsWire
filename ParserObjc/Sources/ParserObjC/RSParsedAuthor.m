//
//  RSParsedAuthor.m
//  RSParserTests
//
//  Created by Brent Simmons on 12/19/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

#import "NSString+RSParser.h"

#import "RSParsedAuthor.h"

@implementation RSParsedAuthor

+ (instancetype)authorWithSingleString:(NSString *)s {

	// The author element in RSS is supposed to be email address — but often it’s a name, and sometimes a URL.
	
	RSParsedAuthor *author = [[self alloc] init];

	if ([s rsparser_contains:@"@"]) {
		author.emailAddress = s;
	}
	else if ([s.lowercaseString hasPrefix:@"http"]) {
		author.url = s;
	}
	else {
		author.name = s;
	}

 	return author;
}

@end
