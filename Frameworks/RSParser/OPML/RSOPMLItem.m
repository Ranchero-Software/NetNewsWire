//
//  RSOPMLItem.m
//  RSParser
//
//  Created by Brent Simmons on 2/28/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

#import <RSParser/RSOPMLItem.h>
#import <RSParser/RSOPMLAttributes.h>
#import <RSParser/RSOPMLFeedSpecifier.h>
#import <RSParser/RSParserInternal.h>


@interface RSOPMLItem ()

@property (nonatomic) NSMutableArray *mutableChildren;

@end


@implementation RSOPMLItem

@synthesize children = _children;
@synthesize feedSpecifier = _feedSpecifier;


- (NSArray *)children {

	return [self.mutableChildren copy];
}


- (void)setChildren:(NSArray *)children {

	_children = children;
	self.mutableChildren = [_children mutableCopy];
}


- (void)addChild:(RSOPMLItem *)child {

	if (!self.mutableChildren) {
		self.mutableChildren = [NSMutableArray new];
	}

	[self.mutableChildren addObject:child];
}


- (RSOPMLFeedSpecifier *)feedSpecifier {

	if (_feedSpecifier) {
		return _feedSpecifier;
	}

	NSString *feedURL = self.attributes.opml_xmlUrl;
	if (RSParserObjectIsEmpty(feedURL)) {
		return nil;
	}

	_feedSpecifier = [[RSOPMLFeedSpecifier alloc] initWithTitle:self.attributes.opml_title feedDescription:self.attributes.opml_description homePageURL:self.attributes.opml_htmlUrl feedURL:feedURL];

	return _feedSpecifier;
}

- (NSString *)titleFromAttributes {
	
	NSString *title = self.attributes.opml_title;
	if (title) {
		return title;
	}
	title = self.attributes.opml_text;
	if (title) {
		return title;
	}
	
	return nil;
}

- (BOOL)isFolder {
	
	return self.mutableChildren.count > 0;
}

@end
