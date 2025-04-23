//
//  RSDatabaseQueue.h
//	RSDatabase
//
//  Created by Brent Simmons on 10/19/13.
//  Copyright (c) 2013 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;
#import "FMDatabase.h"

// This has been deprecated — use DatabaseQueue instead.

@class RSDatabaseQueue;

NS_ASSUME_NONNULL_BEGIN

@protocol RSDatabaseQueueDelegate <NSObject>

@optional

- (void)makeFunctionsForDatabase:(FMDatabase *)database queue:(RSDatabaseQueue *)queue;

@end


// Everything runs on a serial queue.

typedef void (^RSDatabaseBlock)(FMDatabase * __nonnull database);


@interface RSDatabaseQueue : NSObject

@property (nonatomic, strong, readonly) NSString *databasePath; // For debugging use, so you can open the database in sqlite3.

- (instancetype)initWithFilepath:(NSString *)filepath excludeFromBackup:(BOOL)excludeFromBackup;

@property (nonatomic, weak) id<RSDatabaseQueueDelegate> delegate;

// You can feed it the contents of a file that includes comments, etc.
// Lines that start with case-insensitive "create " are executed.
- (void)createTablesUsingStatements:(NSString *)createStatements;
- (void)createTablesUsingStatementsSync:(NSString *)createStatements;

- (void)update:(RSDatabaseBlock)updateBlock;
- (void)updateSync:(RSDatabaseBlock)updateBlock;

- (void)runInDatabase:(RSDatabaseBlock)databaseBlock; // Same as update, but no transaction.

- (void)fetch:(RSDatabaseBlock)fetchBlock;
- (void)fetchSync:(RSDatabaseBlock)fetchBlock;

- (void)vacuum;
- (void)vacuumIfNeeded; // defaultsKey = @"lastVacuumDate"; interval is 6 days.
- (void)vacuumIfNeeded:(NSString *)defaultsKey intervalBetweenVacuums:(NSTimeInterval)intervalBetweenVacuums;

- (NSArray *)arrayWithSingleColumnResultSet:(FMResultSet *)rs;

- (void)close;

@end

NS_ASSUME_NONNULL_END
