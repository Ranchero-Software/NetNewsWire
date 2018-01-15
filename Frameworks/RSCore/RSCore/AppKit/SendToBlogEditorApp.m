//
//  SendToBlogEditorApp.m
//  RSCore
//
//  Created by Brent Simmons on 1/15/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

#import "SendToBlogEditorApp.h"

@interface SendToBlogEditorApp()

@property (nonatomic, readonly) NSAppleEventDescriptor *targetDescriptor;

@property (nonatomic, nullable, readonly) NSString *title;
@property (nonatomic, nullable, readonly) NSString *body;
@property (nonatomic, nullable, readonly) NSString *summary;
@property (nonatomic, nullable, readonly) NSString *link;
@property (nonatomic, nullable, readonly) NSString *permalink;
@property (nonatomic, nullable, readonly) NSString *subject;
@property (nonatomic, nullable, readonly) NSString *creator;
@property (nonatomic, nullable, readonly) NSString *commentsURL;
@property (nonatomic, nullable, readonly) NSString *guid;
@property (nonatomic, nullable, readonly) NSString *sourceName;
@property (nonatomic, nullable, readonly) NSString *sourceHomeURL;
@property (nonatomic, nullable, readonly) NSString *sourceFeedURL;

@end

@implementation SendToBlogEditorApp

- (instancetype)initWithTargetDesciptor:(NSAppleEventDescriptor *)targetDescriptor title:(NSString * _Nullable)title body:(NSString * _Nullable)body summary:(NSString * _Nullable)summary link:(NSString * _Nullable)link permalink:(NSString * _Nullable)permalink subject:(NSString * _Nullable)subject creator:(NSString * _Nullable)creator commentsURL:(NSString * _Nullable)commentsURL guid:(NSString * _Nullable)guid sourceName:(NSString * _Nullable)sourceName sourceHomeURL:(NSString * _Nullable)sourceHomeURL sourceFeedURL:(NSString * _Nullable)sourceFeedURL {

	self = [super init];
	if (!self) {
		return nil;
	}

	_targetDescriptor = targetDescriptor;
	_title = title;
	_body = body;
	_summary = summary;
	_link = link;
	_permalink = permalink;
	_subject = subject;
	_creator = creator;
	_commentsURL = commentsURL;
	_guid = guid;
	_sourceName = sourceName;
	_sourceHomeURL = sourceHomeURL;
	_sourceFeedURL = sourceFeedURL;
	
	return self;
}

const AEKeyword EditDataItemAppleEventClass = 'EBlg';
const AEKeyword EditDataItemAppleEventID = 'oitm';
const AEKeyword DataItemTitle = 'titl';
const AEKeyword DataItemDescription = 'desc';
const AEKeyword DataItemSummary = 'summ';
const AEKeyword DataItemLink = 'link';
const AEKeyword DataItemPermalink = 'plnk';
const AEKeyword DataItemSubject = 'subj';
const AEKeyword DataItemCreator = 'crtr';
const AEKeyword DataItemCommentsURL = 'curl';
const AEKeyword DataItemGUID = 'guid';
const AEKeyword DataItemSourceName = 'snam';
const AEKeyword DataItemSourceHomeURL = 'hurl';
const AEKeyword DataItemSourceFeedURL = 'furl';

- (OSStatus)send {

	NSAppleEventDescriptor *appleEvent = [NSAppleEventDescriptor appleEventWithEventClass:EditDataItemAppleEventClass eventID:EditDataItemAppleEventID targetDescriptor:self.targetDescriptor returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];

	[appleEvent setParamDescriptor:[self paramDescriptor] forKeyword:keyDirectObject];

	return AESendMessage((const AppleEvent *)[appleEvent aeDesc], NULL, kAENoReply | kAECanSwitchLayer | kAEAlwaysInteract, kAEDefaultTimeout);
}

#pragma mark - Private

- (NSAppleEventDescriptor *)paramDescriptor {

	NSAppleEventDescriptor *descriptor = [NSAppleEventDescriptor recordDescriptor];

	[self addToDescriptor:descriptor key:@"title" keyword:DataItemTitle];
	[self addToDescriptor:descriptor key:@"body" keyword:DataItemDescription];
	[self addToDescriptor:descriptor key:@"summary" keyword:DataItemSummary];
	[self addToDescriptor:descriptor key:@"link" keyword:DataItemLink];
	[self addToDescriptor:descriptor key:@"permalink" keyword:DataItemPermalink];
	[self addToDescriptor:descriptor key:@"subject" keyword:DataItemSubject];
	[self addToDescriptor:descriptor key:@"creator" keyword:DataItemCreator];
	[self addToDescriptor:descriptor key:@"commentsURL" keyword:DataItemCommentsURL];
	[self addToDescriptor:descriptor key:@"guid" keyword:DataItemGUID];
	[self addToDescriptor:descriptor key:@"sourceName" keyword:DataItemSourceName];
	[self addToDescriptor:descriptor key:@"sourceHomeURL" keyword:DataItemSourceHomeURL];
	[self addToDescriptor:descriptor key:@"sourceFeedURL" keyword:DataItemSourceFeedURL];

	return descriptor;
}

- (void)addToDescriptor:(NSAppleEventDescriptor *)descriptor key:(NSString *)key keyword:(AEKeyword)keyword {

	NSString *stringValue = (NSString *)[self valueForKey:key];
	if (!stringValue) {
		return;
	}

	NSAppleEventDescriptor *stringDescriptor = [NSAppleEventDescriptor descriptorWithString:stringValue];
	[descriptor setDescriptor:stringDescriptor forKeyword:keyword];
}


@end
