//
//  RSOPMLAttributes.m
//  RSXML
//
//  Created by Brent Simmons on 2/28/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

#import "RSOPMLAttributes.h"
#import "RSXMLInternal.h"


NSString *OPMLTextKey = @"text";
NSString *OPMLTitleKey = @"title";
NSString *OPMLDescriptionKey = @"description";
NSString *OPMLTypeKey = @"type";
NSString *OPMLVersionKey = @"version";
NSString *OPMLHMTLURLKey = @"htmlUrl";
NSString *OPMLXMLURLKey = @"xmlUrl";


@implementation NSDictionary (RSOPMLAttributes)

- (NSString *)opml_text {

	return [self rsxml_objectForCaseInsensitiveKey:OPMLTextKey];
}


- (NSString *)opml_title {

	return [self rsxml_objectForCaseInsensitiveKey:OPMLTitleKey];
}


- (NSString *)opml_description {

	return [self rsxml_objectForCaseInsensitiveKey:OPMLDescriptionKey];
}


- (NSString *)opml_type {

	return [self rsxml_objectForCaseInsensitiveKey:OPMLTypeKey];
}


- (NSString *)opml_version {

	return [self rsxml_objectForCaseInsensitiveKey:OPMLVersionKey];
}


- (NSString *)opml_htmlUrl {

	return [self rsxml_objectForCaseInsensitiveKey:OPMLHMTLURLKey];
}


- (NSString *)opml_xmlUrl {

	return [self rsxml_objectForCaseInsensitiveKey:OPMLXMLURLKey];
}


@end
