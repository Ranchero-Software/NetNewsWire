//
//  FeedParser.m
//  RSXML
//
//  Created by Brent Simmons on 1/4/15.
//  Copyright (c) 2015 Ranchero Software LLC. All rights reserved.
//

#import "RSFeedParser.h"
#import "FeedParser.h"
#import "RSXMLData.h"
#import "RSRSSParser.h"
#import "RSAtomParser.h"

static NSArray *parserClasses(void) {
	
	static NSArray *gParserClasses = nil;
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		gParserClasses = @[[RSRSSParser class], [RSAtomParser class]];
	});
	
	return gParserClasses;
}

static BOOL feedMayBeParseable(RSXMLData *xmlData) {
	
	/*Sanity checks.*/
	
	if (!xmlData.data) {
		return NO;
	}

	/*TODO: check size, type, etc.*/
	
	return YES;
}

static BOOL optimisticCanParseRSSData(const char *bytes, NSUInteger numberOfBytes);
static BOOL optimisticCanParseAtomData(const char *bytes, NSUInteger numberOfBytes);
static BOOL optimisticCanParseRDF(const char *bytes, NSUInteger numberOfBytes);
static BOOL dataIsProbablyHTML(const char *bytes, NSUInteger numberOfBytes);
static BOOL dataIsSomeWeirdException(const char *bytes, NSUInteger numberOfBytes);
static BOOL dataHasLeftCaret(const char *bytes, NSUInteger numberOfBytes);

static const NSUInteger maxNumberOfBytesToSearch = 4096;
static const NSUInteger minNumberOfBytesToSearch = 20;

static Class parserClassForXMLData(RSXMLData *xmlData) {
	
	if (!feedMayBeParseable(xmlData)) {
		return nil;
	}
	
	// TODO: check for things like images and movies and return nil.
	
	const char *bytes = xmlData.data.bytes;
	NSUInteger numberOfBytes = xmlData.data.length;
	
	if (numberOfBytes > minNumberOfBytesToSearch) {
		
		if (numberOfBytes > maxNumberOfBytesToSearch) {
			numberOfBytes = maxNumberOfBytesToSearch;
		}

		if (!dataHasLeftCaret(bytes, numberOfBytes)) {
			return nil;
		}

		if (optimisticCanParseRSSData(bytes, numberOfBytes)) {
			return [RSRSSParser class];
		}
		if (optimisticCanParseAtomData(bytes, numberOfBytes)) {
			return [RSAtomParser class];
		}
		
		if (optimisticCanParseRDF(bytes, numberOfBytes)) {
			return nil; //TODO: parse RDF feeds
		}
		
		if (dataIsProbablyHTML(bytes, numberOfBytes)) {
			return nil;
		}
		if (dataIsSomeWeirdException(bytes, numberOfBytes)) {
			return nil;
		}
	}
	
	for (Class parserClass in parserClasses()) {
		if ([parserClass canParseFeed:xmlData]) {
			return [[parserClass alloc] initWithXMLData:xmlData];
		}
	}
	
	return nil;
}

static id<FeedParser> parserForXMLData(RSXMLData *xmlData) {
	
	Class parserClass = parserClassForXMLData(xmlData);
	if (!parserClass) {
		return nil;
	}
	return [[parserClass alloc] initWithXMLData:xmlData];
}

static BOOL canParseXMLData(RSXMLData *xmlData) {
	
	return parserClassForXMLData(xmlData) != nil;
}

static BOOL didFindString(const char *string, const char *bytes, NSUInteger numberOfBytes) {
	
	char *foundString = strnstr(bytes, string, numberOfBytes);
	return foundString != NULL;
}

static BOOL dataHasLeftCaret(const char *bytes, NSUInteger numberOfBytes) {

	return didFindString("<", bytes, numberOfBytes);
}

static BOOL dataIsProbablyHTML(const char *bytes, NSUInteger numberOfBytes) {
	
	// Won’t catch every single case, which is fine.
	
	if (didFindString("<html", bytes, numberOfBytes)) {
		return YES;
	}
	if (didFindString("<body", bytes, numberOfBytes)) {
		return YES;
	}
	if (didFindString("doctype html", bytes, numberOfBytes)) {
		return YES;
	}
	if (didFindString("DOCTYPE html", bytes, numberOfBytes)) {
		return YES;
	}
	if (didFindString("DOCTYPE HTML", bytes, numberOfBytes)) {
		return YES;
	}
	if (didFindString("<meta", bytes, numberOfBytes)) {
		return YES;
	}
	if (didFindString("<HTML", bytes, numberOfBytes)) {
		return YES;
	}
	
	return NO;
}

static BOOL dataIsSomeWeirdException(const char *bytes, NSUInteger numberOfBytes) {

	if (didFindString("<errors xmlns='http://schemas.google", bytes, numberOfBytes)) {
		return YES;
	}

	return NO;
}

static BOOL optimisticCanParseRDF(const char *bytes, NSUInteger numberOfBytes) {
	
	return didFindString("<rdf:RDF", bytes, numberOfBytes);
}

static BOOL optimisticCanParseRSSData(const char *bytes, NSUInteger numberOfBytes) {
	
	if (!didFindString("<rss", bytes, numberOfBytes)) {
		return NO;
	}
	return didFindString("<channel", bytes, numberOfBytes);
}

static BOOL optimisticCanParseAtomData(const char *bytes, NSUInteger numberOfBytes) {
	
	return didFindString("<feed", bytes, numberOfBytes);
}

static void callCallback(RSParsedFeedBlock callback, RSParsedFeed *parsedFeed, NSError *error) {
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		@autoreleasepool {
			if (callback) {
				callback(parsedFeed, error);
			}
		}
	});
}


#pragma mark - API

BOOL RSCanParseFeed(RSXMLData *xmlData) {

	return canParseXMLData(xmlData);
}

void RSParseFeed(RSXMLData *xmlData, RSParsedFeedBlock callback) {

	dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{

		NSError *error = nil;
		RSParsedFeed *parsedFeed = RSParseFeedSync(xmlData, &error);
		callCallback(callback, parsedFeed, error);
	});
}

RSParsedFeed *RSParseFeedSync(RSXMLData *xmlData, NSError **error) {

	id<FeedParser> parser = parserForXMLData(xmlData);
	return [parser parseFeed:error];
}

