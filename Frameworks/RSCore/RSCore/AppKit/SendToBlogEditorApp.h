//
//  SendToBlogEditorApp.h
//  RSCore
//
//  Created by Brent Simmons on 1/15/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

@import AppKit;

// This is for sending articles to MarsEdit and other apps that implement the send-to-blog-editor Apple events API:
// http://ranchero.com/netnewswire/developers/externalinterface
//
// The first parameter is a target descriptor. The easiest way to get this is probably UserApp.targetDescriptor or +[NSAppleEventDescriptor descriptorWithRunningApplication:].
// This does not care of launching the app in the first place. See UserApp.swift.

NS_ASSUME_NONNULL_BEGIN

@interface SendToBlogEditorApp : NSObject

- (instancetype)initWithTargetDesciptor:(NSAppleEventDescriptor *)targetDescriptor title:(NSString * _Nullable)title body:(NSString * _Nullable)body summary:(NSString * _Nullable)summary link:(NSString * _Nullable)link permalink:(NSString * _Nullable)permalink subject:(NSString * _Nullable)subject creator:(NSString * _Nullable)creator commentsURL:(NSString * _Nullable)commentsURL guid:(NSString * _Nullable)guid sourceName:(NSString * _Nullable)sourceName sourceHomeURL:(NSString * _Nullable)sourceHomeURL sourceFeedURL:(NSString * _Nullable)sourceFeedURL;

- (OSStatus)send; // Actually send the Apple event.

@end

NS_ASSUME_NONNULL_END

