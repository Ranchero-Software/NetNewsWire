//
//  WithLatestFrom.swift
//  CombineExt
//
//  Created by Shai Mishali on 29/08/2019.
//  Copyright © 2020 Combine Community. All rights reserved.
//

#if canImport(Combine)
import Combine

// MARK: - Operator methods
@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public extension Publisher {
  ///  Merges two publishers into a single publisher by combining each value
  ///  from self with the latest value from the second publisher, if any.
  ///
  ///  - parameter other: A second publisher source.
  ///  - parameter resultSelector: Function to invoke for each value from the self combined
  ///                              with the latest value from the second source, if any.
  ///
  ///  - returns: A publisher containing the result of combining each value of the self
  ///             with the latest value from the second publisher, if any, using the
  ///             specified result selector function.
  func withLatestFrom<Other: Publisher, Result>(_ other: Other,
												resultSelector: @escaping (Output, Other.Output) -> Result)
	-> Publishers.WithLatestFrom<Self, Other, Result> {
	  return .init(upstream: self, second: other, resultSelector: resultSelector)
  }

  ///  Merges three publishers into a single publisher by combining each value
  ///  from self with the latest value from the second and third publisher, if any.
  ///
  ///  - parameter other: A second publisher source.
  ///  - parameter other1: A third publisher source.
  ///  - parameter resultSelector: Function to invoke for each value from the self combined
  ///                              with the latest value from the second and third source, if any.
  ///
  ///  - returns: A publisher containing the result of combining each value of the self
  ///             with the latest value from the second and third publisher, if any, using the
  ///             specified result selector function.
  func withLatestFrom<Other: Publisher, Other1: Publisher, Result>(_ other: Other,
																   _ other1: Other1,
																   resultSelector: @escaping (Output, (Other.Output, Other1.Output)) -> Result)
	-> Publishers.WithLatestFrom<Self, AnyPublisher<(Other.Output, Other1.Output), Self.Failure>, Result>
	where Other.Failure == Failure, Other1.Failure == Failure {
	  let combined = other.combineLatest(other1)
		.eraseToAnyPublisher()
	  return .init(upstream: self, second: combined, resultSelector: resultSelector)
  }

  ///  Merges four publishers into a single publisher by combining each value
  ///  from self with the latest value from the second, third and fourth publisher, if any.
  ///
  ///  - parameter other: A second publisher source.
  ///  - parameter other1: A third publisher source.
  ///  - parameter other2: A fourth publisher source.
  ///  - parameter resultSelector: Function to invoke for each value from the self combined
  ///                              with the latest value from the second, third and fourth source, if any.
  ///
  ///  - returns: A publisher containing the result of combining each value of the self
  ///             with the latest value from the second, third and fourth publisher, if any, using the
  ///             specified result selector function.
  func withLatestFrom<Other: Publisher, Other1: Publisher, Other2: Publisher, Result>(_ other: Other,
																					  _ other1: Other1,
																					  _ other2: Other2,
																					  resultSelector: @escaping (Output, (Other.Output, Other1.Output, Other2.Output)) -> Result)
	-> Publishers.WithLatestFrom<Self, AnyPublisher<(Other.Output, Other1.Output, Other2.Output), Self.Failure>, Result>
	where Other.Failure == Failure, Other1.Failure == Failure, Other2.Failure == Failure {
	  let combined = other.combineLatest(other1, other2)
		.eraseToAnyPublisher()
	  return .init(upstream: self, second: combined, resultSelector: resultSelector)
  }

  ///  Upon an emission from self, emit the latest value from the
  ///  second publisher, if any exists.
  ///
  ///  - parameter other: A second publisher source.
  ///
  ///  - returns: A publisher containing the latest value from the second publisher, if any.
  func withLatestFrom<Other: Publisher>(_ other: Other)
	-> Publishers.WithLatestFrom<Self, Other, Other.Output> {
	  return .init(upstream: self, second: other) { $1 }
  }

  /// Upon an emission from self, emit the latest value from the
  /// second and third publisher, if any exists.
  ///
  /// - parameter other: A second publisher source.
  /// - parameter other1: A third publisher source.
  ///
  /// - returns: A publisher containing the latest value from the second and third publisher, if any.
  func withLatestFrom<Other: Publisher, Other1: Publisher>(_ other: Other,
														   _ other1: Other1)
	-> Publishers.WithLatestFrom<Self, AnyPublisher<(Other.Output, Other1.Output), Self.Failure>, (Other.Output, Other1.Output)>
	where Other.Failure == Failure, Other1.Failure == Failure {
	 withLatestFrom(other, other1) { $1 }
  }

  /// Upon an emission from self, emit the latest value from the
  /// second, third and forth publisher, if any exists.
  ///
  /// - parameter other: A second publisher source.
  /// - parameter other1: A third publisher source.
  /// - parameter other2: A forth publisher source.
  ///
  /// - returns: A publisher containing the latest value from the second, third and forth publisher, if any.
  func withLatestFrom<Other: Publisher, Other1: Publisher, Other2: Publisher>(_ other: Other,
																			  _ other1: Other1,
																			  _ other2: Other2)
	-> Publishers.WithLatestFrom<Self, AnyPublisher<(Other.Output, Other1.Output, Other2.Output), Self.Failure>, (Other.Output, Other1.Output, Other2.Output)>
	where Other.Failure == Failure, Other1.Failure == Failure, Other2.Failure == Failure {
	 withLatestFrom(other, other1, other2) { $1 }
  }
}

// MARK: - Publisher
@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public extension Publishers {
  struct WithLatestFrom<Upstream: Publisher,
						Other: Publisher,
						Output>: Publisher where Upstream.Failure == Other.Failure {
	public typealias Failure = Upstream.Failure
	public typealias ResultSelector = (Upstream.Output, Other.Output) -> Output

	private let upstream: Upstream
	private let second: Other
	private let resultSelector: ResultSelector
	private var latestValue: Other.Output?

	init(upstream: Upstream,
		 second: Other,
		 resultSelector: @escaping ResultSelector) {
	  self.upstream = upstream
	  self.second = second
	  self.resultSelector = resultSelector
	}

	public func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
		subscriber.receive(subscription: Subscription(upstream: upstream,
													  downstream: subscriber,
													  second: second,
													  resultSelector: resultSelector))
	}
  }
}

// MARK: - Subscription
@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
private extension Publishers.WithLatestFrom {
  class Subscription<Downstream: Subscriber>: Combine.Subscription, CustomStringConvertible where Downstream.Input == Output, Downstream.Failure == Failure {
	private let resultSelector: ResultSelector
	private var sink: Sink<Upstream, Downstream>?

	private let upstream: Upstream
	private let downstream: Downstream
	private let second: Other

	// Secondary (other) publisher
	private var latestValue: Other.Output?
	private var otherSubscription: Cancellable?
	private var preInitialDemand = Subscribers.Demand.none

	init(upstream: Upstream,
		 downstream: Downstream,
		 second: Other,
		 resultSelector: @escaping ResultSelector) {
		self.upstream = upstream
		self.second = second
		self.downstream = downstream
		self.resultSelector = resultSelector

		trackLatestFromSecond { [weak self] in
			guard let self = self else { return }
			self.request(self.preInitialDemand)
			self.preInitialDemand = .none
		}
	}

	func request(_ demand: Subscribers.Demand) {
		guard latestValue != nil else {
			preInitialDemand += demand
			return
		}

		self.sink?.demand(demand)
	}

	// Create an internal subscription to the `Other` publisher,
	// constantly tracking its latest value
	private func trackLatestFromSecond(onInitialValue: @escaping () -> Void) {
	  var gotInitialValue = false

	  let subscriber = AnySubscriber<Other.Output, Other.Failure>(
		receiveSubscription: { [weak self] subscription in
			self?.otherSubscription = subscription
			subscription.request(.unlimited)
		},
		receiveValue: { [weak self] value in
			guard let self = self else { return .none }
			self.latestValue = value

			if !gotInitialValue {
				// When getting initial value, start pulling values
				// from upstream in the main sink
				self.sink = Sink(upstream: self.upstream,
								 downstream: self.downstream,
								 transformOutput: { [weak self] value in
									guard let self = self,
										  let other = self.latestValue else { return nil }

									return self.resultSelector(value, other)
								 },
								 transformFailure: { $0 })

				// Signal initial value to start fulfilling downstream demand
				gotInitialValue = true
				onInitialValue()
			}

			return .unlimited
		},
		receiveCompletion: nil)

	  self.second.subscribe(subscriber)
	}

	var description: String {
		return "WithLatestFrom.Subscription<\(Output.self), \(Failure.self)>"
	}

	func cancel() {
		sink = nil
		otherSubscription?.cancel()
	}
  }
}
#endif
