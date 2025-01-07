//
//  FMDatabase+QSKit.m
//  RSDatabase
//
//  Created by Brent Simmons on 3/3/14.
//  Copyright (c) 2014 Ranchero Software, LLC. All rights reserved.
//

#import "FMDatabase+RSExtras.h"
#import "NSString+RSDatabase.h"


#define LOG_SQL 0

static void logSQL(NSString *sql) {
#if LOG_SQL
	NSLog(@"sql: %@", sql);
#endif
}


@implementation FMDatabase (RSExtras)


#pragma mark - Deleting

- (BOOL)rs_deleteRowsWhereKey:(NSString *)key inValues:(NSArray *)values tableName:(NSString *)tableName {

	if ([values count] < 1) {
		return YES;
	}

	NSString *placeholders = [NSString rs_SQLValueListWithPlaceholders:values.count];
	NSString *sql = [NSString stringWithFormat:@"delete from %@ where %@ in %@", tableName, key, placeholders];
	logSQL(sql);

	return [self executeUpdate:sql withArgumentsInArray:values];
}


- (BOOL)rs_deleteRowsWhereKey:(NSString *)key equalsValue:(id)value tableName:(NSString *)tableName {

	NSString *sql = [NSString stringWithFormat:@"delete from %@ where %@ = ?", tableName, key];
	logSQL(sql);
	return [self executeUpdate:sql, value];
}


#pragma mark - Selecting

- (FMResultSet *)rs_selectRowsWhereKey:(NSString *)key inValues:(NSArray *)values tableName:(NSString *)tableName {

	NSMutableString *sql = [NSMutableString stringWithFormat:@"select * from %@ where %@ in ", tableName, key];
	NSString *placeholders = [NSString rs_SQLValueListWithPlaceholders:values.count];
	[sql appendString:placeholders];
	logSQL(sql);

	return [self executeQuery:sql withArgumentsInArray:values];
}


- (FMResultSet *)rs_selectRowsWhereKey:(NSString *)key equalsValue:(id)value tableName:(NSString *)tableName {

	NSString *sql = [NSMutableString stringWithFormat:@"select * from %@ where %@ = ?", tableName, key];
	logSQL(sql);
	return [self executeQuery:sql, value];
}


- (FMResultSet *)rs_selectSingleRowWhereKey:(NSString *)key equalsValue:(id)value tableName:(NSString *)tableName {

	NSString *sql = [NSMutableString stringWithFormat:@"select * from %@ where %@ = ? limit 1", tableName, key];
	logSQL(sql);
	return [self executeQuery:sql, value];
}


- (FMResultSet *)rs_selectAllRows:(NSString *)tableName {

	NSString *sql = [NSString stringWithFormat:@"select * from %@", tableName];
	logSQL(sql);
	return [self executeQuery:sql];
}


- (FMResultSet *)rs_selectColumnWithKey:(NSString *)key tableName:(NSString *)tableName {

	NSString *sql = [NSString stringWithFormat:@"select %@ from %@", key, tableName];
	logSQL(sql);
	return [self executeQuery:sql];
}


- (BOOL)rs_rowExistsWithValue:(id)value forKey:(NSString *)key tableName:(NSString *)tableName {

	NSString *sql = [NSString stringWithFormat:@"select 1 from %@ where %@ = ? limit 1;", tableName, key];
	logSQL(sql);
	FMResultSet *rs = [self executeQuery:sql, value];

	return [rs next];
}


- (BOOL)rs_tableIsEmpty:(NSString *)tableName {

	NSString *sql = [NSString stringWithFormat:@"select 1 from %@ limit 1;", tableName];
	logSQL(sql);
	FMResultSet *rs = [self executeQuery:sql];

	BOOL isEmpty = YES;
	while ([rs next]) {
		isEmpty = NO;
	}
	return isEmpty;
}


#pragma mark - Updating

- (BOOL)rs_updateRowsWithDictionary:(NSDictionary *)d whereKey:(NSString *)key equalsValue:(id)value tableName:(NSString *)tableName {

	return [self rs_updateRowsWithDictionary:d whereKey:key inValues:@[value] tableName:tableName];
}


- (BOOL)rs_updateRowsWithDictionary:(NSDictionary *)d whereKey:(NSString *)key inValues:(NSArray *)keyValues tableName:(NSString *)tableName {

	NSMutableArray *keys = [NSMutableArray new];
	NSMutableArray *values = [NSMutableArray new];

	[d enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
		[keys addObject:key];
		[values addObject:obj];
	}];

	NSString *keyPlaceholders = [NSString rs_SQLKeyPlaceholderPairsWithKeys:keys];
	NSString *keyValuesPlaceholder = [NSString rs_SQLValueListWithPlaceholders:keyValues.count];
	NSString *sql = [NSString stringWithFormat:@"update %@ set %@ where %@ in %@", tableName, keyPlaceholders, key, keyValuesPlaceholder];

	NSMutableArray *parameters = values;
	[parameters addObjectsFromArray:keyValues];
	logSQL(sql);

	return [self executeUpdate:sql withArgumentsInArray:parameters];
}


- (BOOL)rs_updateRowsWithValue:(id)value valueKey:(NSString *)valueKey whereKey:(NSString *)key inValues:(NSArray *)keyValues tableName:(NSString *)tableName {
    
    NSDictionary *d = @{valueKey: value};
    return [self rs_updateRowsWithDictionary:d whereKey:key inValues:keyValues tableName:tableName];
}


#pragma mark - Saving

- (BOOL)rs_insertRowWithDictionary:(NSDictionary *)d insertType:(RSDatabaseInsertType)insertType tableName:(NSString *)tableName {

	NSArray *keys = d.allKeys;
	NSArray *values = [d objectsForKeys:keys notFoundMarker:[NSNull null]];
	
	NSString *sqlKeysList = [NSString rs_SQLKeysListWithArray:keys];
	NSString *placeholders = [NSString rs_SQLValueListWithPlaceholders:values.count];

	NSString *sqlBeginning = @"insert into ";
	if (insertType == RSDatabaseInsertOrReplace) {
		sqlBeginning = @"insert or replace into ";
	}
	else if (insertType == RSDatabaseInsertOrIgnore) {
		sqlBeginning = @"insert or ignore into ";
	}

	NSString *sql = [NSString stringWithFormat:@"%@ %@ %@ values %@", sqlBeginning, tableName, sqlKeysList, placeholders];
	logSQL(sql);

	return [self executeUpdate:sql withArgumentsInArray:values];
}

@end

