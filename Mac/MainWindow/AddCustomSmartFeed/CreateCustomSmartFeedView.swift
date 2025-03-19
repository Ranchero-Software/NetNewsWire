//
//  CreateCustomSmartFeedView.swift
//  NetNewsWire
//
//  Created by Mateusz on 19/03/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import SwiftUI

struct CreateCustomSmartFeedView: View {
	@State private var feedName: String
	@State private var conjunction: Bool
	@State private var expressions: [CustomSmartFeedExpression]
	
	typealias Result = (feedName: String, conjunction: Bool, expressions: [CustomSmartFeedExpression])
	var dismiss: (Result?) -> Void
	
	init(
		feedName: String = "",
		conjunction: Bool = false,
		expressions: [CustomSmartFeedExpression] = [(
			field: CustomSmartFeedField.text(.feedID),
			constraint: CustomSmartFeedConstraint.textHas,
			value: CustomSmartFeedValue.text("")
		)],
		dismiss: @escaping (Result?) -> Void)
	{
		self.feedName = feedName
		self.conjunction = conjunction
		self.expressions = expressions
		self.dismiss = dismiss
	}
	
	var body: some View {
		VStack {
			List {
				nameField
					.listRowSeparator(.hidden)
				
				conjunctionPicker
					.listRowSeparator(.hidden)
				
				ForEach(expressions.indices, id: \ .self) { index in
					expressionRow(at: index)
						.listRowSeparator(.hidden)
				}
			}
			.scrollContentBackground(.hidden)
			
			bottomButtons
				.padding()
		}
		.frame(width: 700, height: 400)
	}
	
	var nameField: some View {
		HStack {
			Text("Smart feed name:")
			TextField("", text: $feedName)
				.textFieldStyle(.roundedBorder)
		}
	}
	
	var conjunctionPicker: some View {
		HStack(spacing: 0) {
			Text("Contains items conforming to")
			
			Picker("", selection: $conjunction) {
				Text("any").tag(false)
				Text("all").tag(true)
			}
			.frame(width: 60)
			
			Text(" of the following conditions:")
		}
	}
	
	func expressionRow(at index: Int) -> some View {
		HStack {
			Picker("Field", selection: $expressions[index].field) {
				ForEach(CustomSmartFeedField.TextField.allCases) { field in
					Text(field.rawValue).tag(CustomSmartFeedField.text(field))
				}
				Divider()
				ForEach(CustomSmartFeedField.DateField.allCases) { field in
					Text(field.rawValue).tag(CustomSmartFeedField.date(field))
				}
				Divider()
				ForEach(CustomSmartFeedField.BoolField.allCases) { field in
					Text(field.rawValue).tag(CustomSmartFeedField.bool(field))
				}
			}
			.frame(width: 160)
			.onChange(of: expressions[index].field) { oldValue, newValue in
				// update rest of form based on field type
				switch (oldValue, newValue) {
				case (.text, .text), (.date, .date), (.bool, .bool):
					// no change - no update
					return
				case (_, .text):
					expressions[index].constraint = .textHas
					expressions[index].value = .text("")
				case (_, .date):
					expressions[index].constraint = .dateExact
					expressions[index].value = .date(.now)
				case (_, .bool):
					expressions[index].constraint = .boolExact
					expressions[index].value = .bool(true)
				}
			}
			
			Picker("", selection: $expressions[index].constraint) {
				switch expressions[index].field {
				case .text:
					ForEach(CustomSmartFeedConstraint.textConstraints) { constraint in
						Text(constraint.rawValue).tag(constraint)
					}
				case .date:
					ForEach(CustomSmartFeedConstraint.dateConstraints) { constraint in
						Text(constraint.rawValue).tag(constraint)
					}
				case .bool:
					ForEach(CustomSmartFeedConstraint.boolConstraints) { constraint in
						Text(constraint.rawValue).tag(constraint)
					}
				}
			}
			.frame(width: 120)
			.onChange(of: expressions[index].constraint) { oldValue, newValue in
				// update value type if constraint changes
				if oldValue.valueType != newValue.valueType {
					expressions[index].value = newValue.valueType
				}
			}
			
			switch expressions[index].value {
			case .text(let value):
				TextField("", text: Binding(
					get: { value },
					set: { expressions[index].value = .text($0) }
				))
				.textFieldStyle(.roundedBorder)
			case .date(let value):
				DatePicker("", selection: Binding(
					get: { value },
					set: { expressions[index].value = .date($0) }
				), displayedComponents: .date)
					.fixedSize()
			case .dateRange(let date1, let date2):
				DatePicker("", selection: Binding(
					get: { date1 },
					set: { expressions[index].value = .dateRange($0, date2) }
				), displayedComponents: .date)
					.fixedSize()
				Text("and")
				DatePicker("", selection: Binding(
					get: { date2 },
					set: { expressions[index].value = .dateRange(date1, $0) }
				), displayedComponents: .date)
					.fixedSize()
			case .bool(let value):
				Toggle("", isOn: Binding(
					get: { value },
					set: { expressions[index].value = .bool($0) }
				))
			}
			
			Spacer()
			
			Button(
				action: {
					expressions.append((
						field: CustomSmartFeedField.text(.feedID),
						constraint: CustomSmartFeedConstraint.textHas,
						value: CustomSmartFeedValue.text("")
					))
				},
				label: { Image(systemName: "plus.circle") }
			)
			.buttonStyle(.borderless)
			
			Button(
				action: { expressions.remove(at: index) },
				label: { Image(systemName: "minus.circle") }
			)
			.buttonStyle(.borderless)
			.disabled(expressions.count == 1)
		}
	}
	
	var bottomButtons: some View {
		HStack {
			Spacer()
			
			Button("Cancel") { dismiss(nil) }
				.keyboardShortcut(.cancelAction)
			
			Button("Add") {
				dismiss((feedName, conjunction, expressions))
			}
			.keyboardShortcut(.defaultAction)
		}
	}
}

#Preview {
	CreateCustomSmartFeedView(
		expressions: [(
			field: .date(.datePublished),
			constraint: .dateBetween,
			value: .dateRange(.distantPast, .distantFuture)
		)],
		dismiss: { _ in }
	)
}
