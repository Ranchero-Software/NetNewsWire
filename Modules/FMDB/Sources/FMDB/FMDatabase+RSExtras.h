//
//  FMDatabase+QSKit.h
//  RSDatabase
//
//  Created by Brent Simmons on 3/3/14.
//  Copyright (c) 2014 Ranchero Software, LLC. All rights reserved.
//

#import "FMDatabase.h"

@import Foundation;

typedef NS_ENUM(NSInteger, RSDatabaseInsertType) {
	RSDatabaseInsertNormal,
	RSDatabaseInsertOrReplace,
	RSDatabaseInsertOrIgnore
};

NS_ASSUME_NONNULL_BEGIN

@interface FMDatabase (RSExtras)


// Keys and table names are assumed to be trusted. Values are not.


// delete from tableName where key in (?, ?, ?)

- (BOOL)rs_deleteRowsWhereKey:(NSString *)key inValues:(NSArray *)values tableName:(NSString *)tableName;

// delete from tableName where key=?

- (BOOL)rs_deleteRowsWhereKey:(NSString *)key equalsValue:(id)value tableName:(NSString *)tableName;


// select * from tableName where key in (?, ?, ?)

- (FMResultSet * _Nullable)rs_selectRowsWhereKey:(NSString *)key inValues:(NSArray *)values tableName:(NSString *)tableName;

// select * from tableName where key = ?

- (FMResultSet * _Nullable)rs_selectRowsWhereKey:(NSString *)key equalsValue:(id)value tableName:(NSString *)tableName;

// select * from tableName where key = ? limit 1

- (FMResultSet * _Nullable)rs_selectSingleRowWhereKey:(NSString *)key equalsValue:(id)value tableName:(NSString *)tableName;

// select * from tableName

- (FMResultSet * _Nullable)rs_selectAllRows:(NSString *)tableName;

// select key from tableName;

- (FMResultSet * _Nullable)rs_selectColumnWithKey:(NSString *)key tableName:(NSString *)tableName;

// select 1 from tableName where key = value limit 1;

- (BOOL)rs_rowExistsWithValue:(id)value forKey:(NSString *)key tableName:(NSString *)tableName;

// select 1 from tableName limit 1;

- (BOOL)rs_tableIsEmpty:(NSString *)tableName;


// update tableName set key1=?, key2=? where key = value

- (BOOL)rs_updateRowsWithDictionary:(NSDictionary *)d whereKey:(NSString *)key equalsValue:(id)value tableName:(NSString *)tableName;

// update tableName set key1=?, key2=? where key in (?, ?, ?)

- (BOOL)rs_updateRowsWithDictionary:(NSDictionary *)d whereKey:(NSString *)key inValues:(NSArray *)keyValues tableName:(NSString *)tableName;

// update tableName set valueKey=? where where key in (?, ?, ?)

- (BOOL)rs_updateRowsWithValue:(id)value valueKey:(NSString *)valueKey whereKey:(NSString *)key inValues:(NSArray *)keyValues tableName:(NSString *)tableName;

// insert (or replace, or ignore) into tablename (key1, key2) values (val1, val2)

- (BOOL)rs_insertRowWithDictionary:(NSDictionary *)d insertType:(RSDatabaseInsertType)insertType tableName:(NSString *)tableName;

@end

NS_ASSUME_NONNULL_END
