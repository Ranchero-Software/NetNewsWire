// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
internal enum L10n {
  /// A count of your smart feeds.
  internal static let smartFeedSummaryWidgetDescription = L10n.tr("Localizable", "SmartFeedSummary_Widget_Description")
  /// Your Smart Feed Summary
  internal static let smartFeedSummaryWidgetTitle = L10n.tr("Localizable", "SmartFeedSummary_Widget_Title")
  /// A sneak peak at your starred articles.
  internal static let starredWidgetDescription = L10n.tr("Localizable", "Starred_Widget_Description")
  /// You've not starred any artices.
  internal static let starredWidgetNoItems = L10n.tr("Localizable", "Starred_Widget_NoItems")
  /// Your Starred Articles
  internal static let starredWidgetTitle = L10n.tr("Localizable", "Starred_Widget_Title")
  /// Plural format key: "%#@starred_count@"
  internal static func starredCount(_ p1: Int) -> String {
    return L10n.tr("Localizable", "StarredCount", p1)
  }
  /// A sneak peak at recently published unread articles.
  internal static let todayWidgetDescription = L10n.tr("Localizable", "Today_Widget_Description")
  /// There are no recent articles to read.
  internal static let todayWidgetNoItems = L10n.tr("Localizable", "Today_Widget_NoItems")
  /// Your Today Articles
  internal static let todayWidgetTitle = L10n.tr("Localizable", "Today_Widget_Title")
  /// Plural format key: "%#@today_count@"
  internal static func todayCount(_ p1: Int) -> String {
    return L10n.tr("Localizable", "TodayCount", p1)
  }
  /// A sneak peak at your unread articles.
  internal static let unreadWidgetDescription = L10n.tr("Localizable", "Unread_Widget_Description")
  /// There's nothing to read right now.
  internal static let unreadWidgetNoItems = L10n.tr("Localizable", "Unread_Widget_NoItems")
  /// Your Unread Articles
  internal static let unreadWidgetTitle = L10n.tr("Localizable", "Unread_Widget_Title")
  /// Plural format key: "%#@unread_count@"
  internal static func unreadCount(_ p1: Int) -> String {
    return L10n.tr("Localizable", "UnreadCount", p1)
  }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension L10n {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
    let format = BundleToken.bundle.localizedString(forKey: key, value: nil, table: table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

// swiftlint:disable convenience_type
private final class BundleToken {
  static let bundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle(for: BundleToken.self)
    #endif
  }()
}
// swiftlint:enable convenience_type
