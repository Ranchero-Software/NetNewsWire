//
//  RSDatabaseQueue.m
//	RSDatabase
//
//  Created by Brent Simmons on 10/19/13.
//  Copyright (c) 2013 Ranchero Software, LLC. All rights reserved.
//

#import "RSDatabaseQueue.h"
#import <sqlite3.h>

// This has been deprecated — use DatabaseQueue instead.

@interface RSDatabaseQueue ()

@property (nonatomic, strong, readwrite) NSString *databasePath;
@property (nonatomic, assign) BOOL excludeFromBackup;
@property (nonatomic, strong, readonly) dispatch_queue_t serialDispatchQueue;
@property (nonatomic) BOOL closing;
@property (nonatomic) BOOL closed;

@end


@implementation RSDatabaseQueue


#pragma mark - Init

- (instancetype)initWithFilepath:(NSString *)filepath excludeFromBackup:(BOOL)excludeFromBackup {

	self = [super init];
	if (self == nil)
		return self;

	_databasePath = filepath;

	_serialDispatchQueue = dispatch_queue_create([[NSString stringWithFormat:@"RSDatabaseQueue serial queue - %@", filepath.lastPathComponent] UTF8String], DISPATCH_QUEUE_SERIAL);

	_excludeFromBackup = excludeFromBackup;

	return self;
}


#pragma mark - Database

- (FMDatabase *)database {

	/*I've always done it this way -- kept a per-thread database in the threadDictionary -- and I know it's solid. Maybe it's not necessary with a serial queue, but my understanding was that SQLite wanted a different database per thread (and a serial queue may run on different threads).*/

	if (self.closed) {
		return nil;
	}
	
	NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
	FMDatabase *database = threadDictionary[self.databasePath];

	if (!database || !database.open) {

		database = [FMDatabase databaseWithPath:self.databasePath];
		[database open];
		[database executeUpdate:@"PRAGMA synchronous = 1;"];
		[database setShouldCacheStatements:YES];

		if ([self.delegate respondsToSelector:@selector(makeFunctionsForDatabase:queue:)]) {
			[self.delegate makeFunctionsForDatabase:database queue:self];
		}
		
		threadDictionary[self.databasePath] = database;

		if (self.excludeFromBackup) {

			static dispatch_once_t onceToken;
			dispatch_once(&onceToken, ^{
				NSURL *URL = [NSURL fileURLWithPath:self.databasePath isDirectory:NO];
				NSError *error = nil;
				[URL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:&error];
			});
		}
	}

	return database;
}

#pragma mark - API

- (void)createTablesUsingStatements:(NSString *)createStatements {

	[self runInDatabase:^(FMDatabase *database) {
		[self runCreateStatements:createStatements database:database];
	}];
}


- (void)createTablesUsingStatementsSync:(NSString *)createStatements {

	[self runInDatabaseSync:^(FMDatabase *database) {
		[self runCreateStatements:createStatements database:database];
	}];
}

- (void)runCreateStatements:(NSString *)createStatements database:(FMDatabase *)database {

	[createStatements enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
		if ([line.lowercaseString hasPrefix:@"create "]) {
			[database executeUpdate:line];
		}
		*stop = NO;
	}];
}

- (void)update:(RSDatabaseBlock)updateBlock {

	dispatch_async(self.serialDispatchQueue, ^{
		[self runInTransaction:updateBlock];
	});
}


- (void)updateSync:(RSDatabaseBlock)updateBlock {

	dispatch_sync(self.serialDispatchQueue, ^{
		[self runInTransaction:updateBlock];
	});
}

- (void)runInTransaction:(RSDatabaseBlock)databaseBlock {

	@autoreleasepool {
		FMDatabase *database = [self database];
		[database beginTransaction];
		databaseBlock(database);
		[database commit];
	}
}

- (void)runInDatabase:(RSDatabaseBlock)databaseBlock {

	dispatch_async(self.serialDispatchQueue, ^{
		@autoreleasepool {
			databaseBlock([self database]);
		}
	});
}


- (void)runInDatabaseSync:(RSDatabaseBlock)databaseBlock {

	dispatch_sync(self.serialDispatchQueue, ^{
		@autoreleasepool {
			databaseBlock([self database]);
		}
	});
}

- (void)fetch:(RSDatabaseBlock)fetchBlock {

	[self runInDatabase:fetchBlock];
}


- (void)fetchSync:(RSDatabaseBlock)fetchBlock {

	dispatch_sync(self.serialDispatchQueue, ^{
		@autoreleasepool {
			fetchBlock([self database]);
		}
	});
}


- (void)vacuum {

	dispatch_async(self.serialDispatchQueue, ^{
		@autoreleasepool {
			[[self database] executeUpdate:@"vacuum;"];
		}
	});
}

- (void)vacuumIfNeeded {
	
	NSTimeInterval interval = (24 * 60 * 60) * 6; // 6 days
	[self vacuumIfNeeded:@"lastVacuumDate" intervalBetweenVacuums:interval];
}


- (void)vacuumIfNeeded:(NSString *)defaultsKey intervalBetweenVacuums:(NSTimeInterval)intervalBetweenVacuums {
	
	NSDate *lastVacuumDate = [[NSUserDefaults standardUserDefaults] objectForKey:defaultsKey];
	if (!lastVacuumDate || ![lastVacuumDate isKindOfClass:[NSDate class]]) {
		[[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:defaultsKey];
		return;
	}
	
	NSDate *cutoffDate = [[NSDate date] dateByAddingTimeInterval: -(intervalBetweenVacuums)];
	if ([cutoffDate earlierDate:lastVacuumDate] == lastVacuumDate) {
		[[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:defaultsKey];
		[self vacuum];
	}
}


- (NSArray *)arrayWithSingleColumnResultSet:(FMResultSet *)rs {

	NSMutableArray *results = [NSMutableArray new];
	while ([rs next]) {
		id oneObject = [rs objectForColumnIndex:0];
		if (oneObject) {
			[results addObject:oneObject];
		}
	}

	return [results copy];
}

- (void)close {
	self.closing = YES;
	[self runInDatabaseSync:^(FMDatabase *database) {
		self.closed = YES;
		[database close];
	}];
}

@end

