//
//  RSHTMLMetadata.m
//  RSParser
//
//  Created by Brent Simmons on 3/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

#import <RSParser/RSHTMLMetadata.h>
#import <RSParser/RSParserInternal.h>

static NSString *urlStringFromDictionary(NSDictionary *d);
static NSString *absoluteURLStringWithRelativeURLString(NSString *relativeURLString, NSString *baseURLString);
static NSString *absoluteURLStringWithDictionary(NSDictionary *d, NSString *baseURLString);
static NSArray *objectsOfClassWithDictionaries(Class class, NSArray *dictionaries, NSString *baseURLString);
static NSString *relValue(NSDictionary *d);
static BOOL typeIsFeedType(NSString *type);

static NSString *kShortcutIconRelValue = @"shortcut icon";
static NSString *kHrefKey = @"href";
static NSString *kSrcKey = @"src";
static NSString *kAppleTouchIconValue = @"apple-touch-icon";
static NSString *kAppleTouchIconPrecomposedValue = @"apple-touch-icon-precomposed";
static NSString *kSizesKey = @"sizes";
static NSString *kTitleKey = @"title";
static NSString *kRelKey = @"rel";
static NSString *kAlternateKey = @"alternate";
static NSString *kRSSSuffix = @"/rss+xml";
static NSString *kAtomSuffix = @"/atom+xml";
static NSString *kTypeKey = @"type";

@interface RSHTMLMetadataAppleTouchIcon ()

- (instancetype)initWithDictionary:(NSDictionary *)d baseURLString:(NSString *)baseURLString;

@end


@interface RSHTMLMetadataFeedLink ()

- (instancetype)initWithDictionary:(NSDictionary *)d baseURLString:(NSString *)baseURLString;

@end


@implementation RSHTMLMetadata


#pragma mark - Init

- (instancetype)initWithURLString:(NSString *)urlString dictionaries:(NSArray <NSDictionary *> *)dictionaries {

	self = [super init];
	if (!self) {
		return nil;
	}

	_baseURLString = urlString;
	_dictionaries = dictionaries;
	_faviconLink = [self resolvedLinkFromFirstDictionaryWithMatchingRel:kShortcutIconRelValue];

	NSArray *appleTouchIconDictionaries = [self appleTouchIconDictionaries];
	_appleTouchIcons = objectsOfClassWithDictionaries([RSHTMLMetadataAppleTouchIcon class], appleTouchIconDictionaries, urlString);

	NSArray *feedLinkDictionaries = [self feedLinkDictionaries];
	_feedLinks = objectsOfClassWithDictionaries([RSHTMLMetadataFeedLink class], feedLinkDictionaries, urlString);

	return self;
}


#pragma mark - Private

- (NSDictionary *)firstDictionaryWithMatchingRel:(NSString *)valueToMatch {

	// Case-insensitive.

	for (NSDictionary *oneDictionary in self.dictionaries) {

		NSString *oneRelValue = relValue(oneDictionary);
		if (oneRelValue && [oneRelValue compare:valueToMatch options:NSCaseInsensitiveSearch] == NSOrderedSame) {
			return oneDictionary;
		}
	}

	return nil;
}


- (NSArray *)appleTouchIconDictionaries {

	NSMutableArray *dictionaries = [NSMutableArray new];

	for (NSDictionary *oneDictionary in self.dictionaries) {

		NSString *oneRelValue = relValue(oneDictionary).lowercaseString;
		if ([oneRelValue isEqualToString:kAppleTouchIconValue] || [oneRelValue isEqualToString:kAppleTouchIconPrecomposedValue]) {
			[dictionaries addObject:oneDictionary];
		}
	}

	return dictionaries;
}


- (NSArray *)feedLinkDictionaries {

	NSMutableArray *dictionaries = [NSMutableArray new];

	for (NSDictionary *oneDictionary in self.dictionaries) {

		NSString *oneRelValue = relValue(oneDictionary).lowercaseString;
		if (![oneRelValue isEqualToString:kAlternateKey]) {
			continue;
		}

		NSString *oneType = [oneDictionary rsparser_objectForCaseInsensitiveKey:kTypeKey];
		if (!typeIsFeedType(oneType)) {
			continue;
		}

		if (RSParserStringIsEmpty(urlStringFromDictionary(oneDictionary))) {
			continue;
		}

		[dictionaries addObject:oneDictionary];
	}

	return dictionaries;
}


- (NSString *)resolvedLinkFromFirstDictionaryWithMatchingRel:(NSString *)relValue {

	NSDictionary *d = [self firstDictionaryWithMatchingRel:relValue];
	return absoluteURLStringWithDictionary(d, self.baseURLString);
}


@end


static NSString *relValue(NSDictionary *d) {

	return [d rsparser_objectForCaseInsensitiveKey:kRelKey];
}


static NSString *urlStringFromDictionary(NSDictionary *d) {

	NSString *urlString = [d rsparser_objectForCaseInsensitiveKey:kHrefKey];
	if (urlString) {
		return urlString;
	}

	return [d rsparser_objectForCaseInsensitiveKey:kSrcKey];
}


static NSString *absoluteURLStringWithRelativeURLString(NSString *relativeURLString, NSString *baseURLString) {

	NSURL *url = [NSURL URLWithString:baseURLString];
	if (!url) {
		return nil;
	}

	NSURL *absoluteURL = [NSURL URLWithString:relativeURLString relativeToURL:url];
	return absoluteURL.absoluteString;
}


static NSString *absoluteURLStringWithDictionary(NSDictionary *d, NSString *baseURLString) {

	NSString *urlString = urlStringFromDictionary(d);
	if (RSParserStringIsEmpty(urlString)) {
		return nil;
	}
	return absoluteURLStringWithRelativeURLString(urlString, baseURLString);
}


static NSArray *objectsOfClassWithDictionaries(Class class, NSArray *dictionaries, NSString *baseURLString) {

	NSMutableArray *objects = [NSMutableArray new];

	for (NSDictionary *oneDictionary in dictionaries) {

		id oneObject = [[class alloc] initWithDictionary:oneDictionary baseURLString:baseURLString];
		if (oneObject) {
			[objects addObject:oneObject];
		}
	}

	return [objects copy];
}


static BOOL typeIsFeedType(NSString *type) {

	type = type.lowercaseString;
	return [type hasSuffix:kRSSSuffix] || [type hasSuffix:kAtomSuffix];
}


@implementation RSHTMLMetadataAppleTouchIcon


- (instancetype)initWithDictionary:(NSDictionary *)d baseURLString:(NSString *)baseURLString {

	self = [super init];
	if (!self) {
		return nil;
	}

	_urlString = absoluteURLStringWithDictionary(d, baseURLString);
	_sizes = [d rsparser_objectForCaseInsensitiveKey:kSizesKey];
	_rel = [d rsparser_objectForCaseInsensitiveKey:kRelKey];

	return self;
}


@end


@implementation RSHTMLMetadataFeedLink


- (instancetype)initWithDictionary:(NSDictionary *)d baseURLString:(NSString *)baseURLString {

	self = [super init];
	if (!self) {
		return nil;
	}

	_urlString = absoluteURLStringWithDictionary(d, baseURLString);
	_title = [d rsparser_objectForCaseInsensitiveKey:kTitleKey];
	_type = [d rsparser_objectForCaseInsensitiveKey:kTypeKey];

	return self;
}


@end

