//
//  RSOPMLItem.m
//  RSXML
//
//  Created by Brent Simmons on 2/28/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

#import "RSOPMLItem.h"
#import "RSOPMLAttributes.h"
#import "RSOPMLFeedSpecifier.h"
#import "RSXMLInternal.h"


@interface RSOPMLItem ()

@property (nonatomic) NSMutableArray *mutableChildren;

@end


@implementation RSOPMLItem

@synthesize children = _children;
@synthesize OPMLFeedSpecifier = _OPMLFeedSpecifier;


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


- (RSOPMLFeedSpecifier *)OPMLFeedSpecifier {

	if (_OPMLFeedSpecifier) {
		return _OPMLFeedSpecifier;
	}

	NSString *feedURL = self.attributes.opml_xmlUrl;
	if (RSXMLIsEmpty(feedURL)) {
		return nil;
	}

	_OPMLFeedSpecifier = [[RSOPMLFeedSpecifier alloc] initWithTitle:self.attributes.opml_title feedDescription:self.attributes.opml_description homePageURL:self.attributes.opml_htmlUrl feedURL:feedURL];

	return _OPMLFeedSpecifier;
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
