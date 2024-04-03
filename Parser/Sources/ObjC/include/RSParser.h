//
//  RSParser.h
//  RSParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;


#import "../ParserData.h"
#import "../RSDateParser.h"

// OPML

#import "../RSOPMLParser.h"
#import "../RSOPMLDocument.h"
#import "../RSOPMLItem.h"
#import "../RSOPMLAttributes.h"
#import "../RSOPMLFeedSpecifier.h"
#import "../RSOPMLError.h"

// For writing your own XML parser.

#import "../RSSAXParser.h"

// You should use FeedParser (Swift) instead of these two specific parsers
// and the objects they create.
// But they’re available if you want them.

#import "../RSRSSParser.h"
#import "../RSAtomParser.h"
#import "../RSParsedFeed.h"
#import "../RSParsedArticle.h"
#import "../RSParsedEnclosure.h"
#import "../RSParsedAuthor.h"

// HTML

#import "../RSHTMLMetadataParser.h"
#import "../RSHTMLMetadata.h"
#import "../RSHTMLLinkParser.h"
#import "../RSSAXHTMLParser.h" // For writing your own HTML parser.
#import "../RSHTMLTag.h"

// Utilities

#import "../NSData+RSParser.h"
#import "../NSString+RSParser.h"






