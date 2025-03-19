//
//  CustomSmartFeedExpression.swift
//  NetNewsWire
//
//  Created by Mateusz on 19/03/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

typealias CustomSmartFeedExpression = (field: CustomSmartFeedField, constraint: CustomSmartFeedConstraint, value: CustomSmartFeedValue)

extension [CustomSmartFeedExpression] {
	func query(conjunction: Bool) -> String {
		return self
			.compactMap { (field, constraint, value) in
				switch (field, constraint, value) {
				// accept text fields only if value type is text and constraint is text
				case (.text(let field), _, .text) where CustomSmartFeedConstraint.textConstraints.contains(constraint):
					return "\(field.rawValue) \(constraint.queryFragment)"
				// accept date between field only if value type is date range
				case (.date(let field), .dateBetween, .dateRange):
					return "\(field.rawValue) \(constraint.queryFragment)"
				// accept date fields only if value type is date and constraint is date
				case (.date(let field), _, .date) where CustomSmartFeedConstraint.dateConstraints.contains(constraint):
					return "\(field.rawValue) \(constraint.queryFragment)"
				// ignore everything else
				default:
					return nil
				}
			}
			.map { "(\($0))" }
			.joined(separator: conjunction ? " AND " : " OR ")
	}
	
	var parameters: [String] {
		return self.flatMap { (_, _, value) in
			switch value {
			case .text(let value): return [value]
			case .date(let date): return [String(Int(date.timeIntervalSince1970))]
			case .dateRange(let date1, let date2): return [
				String(Int(date1.timeIntervalSince1970)),
				String(Int(date2.timeIntervalSince1970)),
			]
			case .bool(let value): return [value ? "1" : "0"]
			}
		}
	}
}

enum CustomSmartFeedField: Hashable {
	case text(TextField)
	case date(DateField)
	case bool(BoolField)
	
	enum TextField: String, CaseIterable, Identifiable, Hashable {
		case feedID, uniqueID, title, contentHTML, contentText, url, externalURL
		var id: String { rawValue }
	}
	
	enum DateField: String, CaseIterable, Identifiable, Hashable {
		case datePublished, dateModified
		var id: String { rawValue }
	}
	
	enum BoolField: String, CaseIterable, Identifiable, Hashable {
		case read, starred
		var id: String { rawValue }
	}
}

enum CustomSmartFeedConstraint: String, CaseIterable, Identifiable, Hashable {
	case textHas, textHasNot, textStartsWith, textEndsWith, textExact
	case dateBefore, dateAfter, dateBetween, dateExact
	case boolExact
	var id: String { rawValue }
	
	static var textConstraints: [CustomSmartFeedConstraint] {
		[.textHas, .textHasNot, .textStartsWith, .textEndsWith, .textExact]
	}
	
	static var dateConstraints: [CustomSmartFeedConstraint] {
		[.dateBefore, .dateAfter, .dateBetween, .dateExact]
	}
	
	static var boolConstraints: [CustomSmartFeedConstraint] {
		[.boolExact]
	}
	
	var queryFragment: String {
		switch self {
		case .textHas: return "LIKE '%' || ? || '%'"
		case .textHasNot: return "NOT LIKE '%' || ? || '%'"
		case .textStartsWith: return  "LIKE ? || '%'"
		case .textEndsWith: return  "LIKE '%' || ?"
		case .textExact, .dateExact, .boolExact: return "= ?"
		case .dateBefore: return  "< ?"
		case .dateAfter: return  "> ?"
		case .dateBetween: return  "BETWEEN ? AND ?"
		}
	}
	
	var valueType: CustomSmartFeedValue {
		switch self {
		case .textHas, .textHasNot, .textStartsWith, .textEndsWith, .textExact:
			return .text("")
		case .dateBefore, .dateAfter, .dateExact:
			return .date(.now)
		case .dateBetween:
			return .dateRange(.now, .now)
		case .boolExact:
			return .bool(true)
		}
	}
}

enum CustomSmartFeedValue: Equatable {
	case text(String)
	case date(Date)
	case dateRange(Date, Date)
	case bool(Bool)
}
