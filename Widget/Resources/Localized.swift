// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
internal enum L10n {
  /// Plural format key: "%#@localized_count@"
  internal static func localizedCount(_ p1: Int) -> String {
    return L10n.tr("Localizable", "LOCALIZED_COUNT", p1)
  }
  /// Your smart feeds, summarized.
  internal static let smartFeedSummaryWidgetDescription = L10n.tr("Localizable", "SMARTFEEDSUMMARY_WIDGET_DESCRIPTION")
  /// Your Smart Feed Summary
  internal static let smartFeedSummaryWidgetTitle = L10n.tr("Localizable", "SMARTFEEDSUMMARY_WIDGET_TITLE")
  /// Starred
  internal static let starred = L10n.tr("Localizable", "STARRED")
  /// A sneak peek at your starred articles.
  internal static let starredWidgetDescription = L10n.tr("Localizable", "STARRED_WIDGET_DESCRIPTION")
  /// When you mark articles as Starred, they'll appear here.
  internal static let starredWidgetNoItems = L10n.tr("Localizable", "STARRED_WIDGET_NOITEMS")
  /// Starred
  internal static let starredWidgetNoItemsTitle = L10n.tr("Localizable", "STARRED_WIDGET_NOITEMSTITLE")
  /// Your Starred Articles
  internal static let starredWidgetTitle = L10n.tr("Localizable", "STARRED_WIDGET_TITLE")
  /// Plural format key: "%#@starred_count@"
  internal static func starredCount(_ p1: Int) -> String {
    return L10n.tr("Localizable", "STARRED_COUNT", p1)
  }
  /// Today  
  internal static let today = L10n.tr("Localizable", "TODAY")
  /// A sneak peek at recently published unread articles.
  internal static let todayWidgetDescription = L10n.tr("Localizable", "TODAY_WIDGET_DESCRIPTION")
  /// There are no recent unread articles left to read.
  internal static let todayWidgetNoItems = L10n.tr("Localizable", "TODAY_WIDGET_NOITEMS")
  /// Today
  internal static let todayWidgetNoItemsTitle = L10n.tr("Localizable", "TODAY_WIDGET_NOITEMSTITLE")
  /// Your Today Articles
  internal static let todayWidgetTitle = L10n.tr("Localizable", "TODAY_WIDGET_TITLE")
  /// Plural format key: "%#@today_count@"
  internal static func todayCount(_ p1: Int) -> String {
    return L10n.tr("Localizable", "TODAY_COUNT", p1)
  }
  /// Unread
  internal static let unread = L10n.tr("Localizable", "UNREAD")
  /// A sneak peek at your unread articles.
  internal static let unreadWidgetDescription = L10n.tr("Localizable", "UNREAD_WIDGET_DESCRIPTION")
  /// There are no unread articles left to read.
  internal static let unreadWidgetNoItems = L10n.tr("Localizable", "UNREAD_WIDGET_NOITEMS")
  /// Unread
  internal static let unreadWidgetNoItemsTitle = L10n.tr("Localizable", "UNREAD_WIDGET_NOITEMSTITLE")
  /// Your Unread Articles
  internal static let unreadWidgetTitle = L10n.tr("Localizable", "UNREAD_WIDGET_TITLE")
  /// Plural format key: "%#@unread_count@"
  internal static func unreadCount(_ p1: Int) -> String {
    return L10n.tr("Localizable", "UNREAD_COUNT", p1)
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
