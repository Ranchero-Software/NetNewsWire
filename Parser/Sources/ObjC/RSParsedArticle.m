//
//  RSParsedArticle.m
//  RSParser
//
//  Created by Brent Simmons on 12/6/14.
//  Copyright (c) 2014 Ranchero Software LLC. All rights reserved.
//


#import "RSParsedArticle.h"
#import "RSParserInternal.h"
#import "NSString+RSParser.h"
#import "RSParsedAuthor.h"
#import "RSParsedEnclosure.h"



@implementation RSParsedArticle


#pragma mark - Init

- (instancetype)initWithFeedURL:(NSString *)feedURL {
	
	NSParameterAssert(feedURL != nil);
	
	self = [super init];
	if (!self) {
		return nil;
	}
	
	_feedURL = feedURL;
	_dateParsed = [NSDate date];
	
	return self;
}


#pragma mark - Enclosures

- (void)addEnclosure:(RSParsedEnclosure *)enclosure {

	if (self.enclosures) {
		self.enclosures = [self.enclosures setByAddingObject:enclosure];
	}
	else {
		self.enclosures = [NSSet setWithObject:enclosure];
	}
}

#pragma mark - Authors

- (void)addAuthor:(RSParsedAuthor *)author {

	if (self.authors) {
		self.authors = [self.authors setByAddingObject:author];
	}
	else {
		self.authors = [NSSet setWithObject:author];
	}
}

#pragma mark - articleID

- (NSString *)articleID {

	if (self.guid) {
		return self.guid;
	}
	
	if (!_articleID) {
		_articleID = [self calculatedArticleID];
	}
	
	return _articleID;
}


- (NSString *)calculatedArticleID {

	/*Concatenate a combination of properties when no guid. Then hash the result.
	 In general, feeds should have guids. When they don't, re-runs are very likely,
	 because there's no other 100% reliable way to determine identity.
	 This is intended to create an ID unique inside a feed, but not globally unique.
	 Not suitable for a database ID, in other words.*/

	NSMutableString *s = [NSMutableString stringWithString:@""];
	
	NSString *datePublishedTimeStampString = nil;
	if (self.datePublished) {
		datePublishedTimeStampString = [NSString stringWithFormat:@"%.0f", self.datePublished.timeIntervalSince1970];
	}

	// Ideally we have a permalink and a pubDate. Either one would probably be a good guid, but together they should be rock-solid. (In theory. Feeds are buggy, though.)
	if (!RSParserStringIsEmpty(self.permalink) && datePublishedTimeStampString) {
		[s appendString:self.permalink];
		[s appendString:datePublishedTimeStampString];
	}

	else if (!RSParserStringIsEmpty(self.link) && datePublishedTimeStampString) {
		[s appendString:self.link];
		[s appendString:datePublishedTimeStampString];
	}

	else if (!RSParserStringIsEmpty(self.title) && datePublishedTimeStampString) {
		[s appendString:self.title];
		[s appendString:datePublishedTimeStampString];
	}

	else if (datePublishedTimeStampString) {
		[s appendString:datePublishedTimeStampString];
	}

	else if (!RSParserStringIsEmpty(self.permalink)) {
		[s appendString:self.permalink];
	}

	else if (!RSParserStringIsEmpty(self.link)) {
		[s appendString:self.link];
	}

	else if (!RSParserStringIsEmpty(self.title)) {
		[s appendString:self.title];
	}
	
	else if (!RSParserStringIsEmpty(self.body)) {
		[s appendString:self.body];
	}

	return [s rsparser_md5Hash];
}

@end

