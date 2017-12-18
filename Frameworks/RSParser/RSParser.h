//
//  RSParser.h
//  RSParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

// To parse RSS, Atom, JSON Feed, and RSS-in-JSON the easy way, see FeedParser.swift.

#import <RSParser/ParserData.h>

// Dates

#import <RSParser/RSDateParser.h>

// OPML

#import <RSParser/RSOPMLParser.h>
#import <RSParser/RSOPMLDocument.h>
#import <RSParser/RSOPMLItem.h>
#import <RSParser/RSOPMLAttributes.h>
#import <RSParser/RSOPMLFeedSpecifier.h>
#import <RSParser/RSOPMLError.h>

// For writing your own XML parser.

#import <RSParser/RSSAXParser.h>

// You should use FeedParser (Swift) instead of these two specific parsers
// and the objects they create.
// But they’re available if you want them.

#import <RSParser/RSRSSParser.h>
#import <RSParser/RSAtomParser.h>
#import <RSParser/RSParsedFeed.h>
#import <RSParser/RSParsedArticle.h>
#import <RSParser/RSParsedEnclosure.h>

// HTML

#import <RSParser/RSHTMLMetadataParser.h>
#import <RSParser/RSHTMLMetadata.h>
#import <RSParser/RSHTMLLinkParser.h>
#import <RSParser/RSSAXHTMLParser.h> // For writing your own HTML parser.
#import <RSParser/RSHTMLTag.h>

// Utilities

#import <RSParser/NSData+RSParser.h>
#import <RSParser/NSString+RSParser.h>
