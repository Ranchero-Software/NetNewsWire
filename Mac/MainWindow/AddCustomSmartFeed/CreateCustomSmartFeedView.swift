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
		expressions: [CustomSmartFeedExpression] = [
			.init(field: .title, constraint: .has, value: "")
		],
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
		.frame(width: 620, height: 400)
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
				Text("Feed ID").tag(CustomSmartFeedExpression.Field.feedID)
				Text("Title").tag(CustomSmartFeedExpression.Field.title)
				Text("Content HTML").tag(CustomSmartFeedExpression.Field.contentHTML)
				Text("Content Text").tag(CustomSmartFeedExpression.Field.contentText)
				Text("External URL").tag(CustomSmartFeedExpression.Field.externalURL)
			}
			.frame(width: 160)
			
			Picker("", selection: $expressions[index].constraint) {
				   Text("has").tag(CustomSmartFeedExpression.Constraint.has)
				   Text("doesn't have").tag(CustomSmartFeedExpression.Constraint.hasNot)
				   Text("starts with").tag(CustomSmartFeedExpression.Constraint.startsWith)
				   Text("ends with").tag(CustomSmartFeedExpression.Constraint.endsWith)
				   Text("is exactly").tag(CustomSmartFeedExpression.Constraint.exact)
			   }
			   .frame(width: 120)
			
			TextField("", text: $expressions[index].value)
				  .textFieldStyle(.roundedBorder)
			
			Spacer()
			
			Button(
				action: {
					expressions.append(
						.init(field: .title, constraint: .has, value: "")
					)
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
		dismiss: { _ in }
	)
}
