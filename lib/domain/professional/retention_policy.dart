/// How long captured material is kept before it deletes itself.
///
/// The maximum is 15 days and the countdown is always visible (design.md §5.6).
final class RetentionPolicy {
  /// Creates a policy of [days], clamped to the supported range.
  RetentionPolicy(int days)
    : days = days < minimumDays
          ? minimumDays
          : (days > maximumDays ? maximumDays : days);

  /// The shortest retention offered.
  static const int minimumDays = 1;

  /// The longest retention offered. A hard product limit, not a default.
  static const int maximumDays = 15;

  /// The choices shown in the UI.
  static const List<int> choices = <int>[1, 3, 7, 15];

  /// The default when the user has not chosen.
  static final RetentionPolicy standard = RetentionPolicy(7);

  /// How many days material is kept.
  final int days;

  /// When something created at [createdAt] expires.
  DateTime expiryOf(DateTime createdAt) => createdAt.add(Duration(days: days));

  /// Whole days left for something created at [createdAt], as of [now].
  ///
  /// Zero means "expires today"; negative values are clamped to zero, because a
  /// countdown never runs backwards in the UI.
  int daysRemaining(DateTime createdAt, DateTime now) {
    final Duration left = expiryOf(createdAt).difference(now);
    if (left.isNegative) return 0;
    return left.inDays;
  }

  /// Whether something created at [createdAt] should already be gone.
  bool hasExpired(DateTime createdAt, DateTime now) =>
      !expiryOf(createdAt).isAfter(now);

  /// The retention window as a duration.
  Duration get duration => Duration(days: days);

  @override
  bool operator ==(Object other) =>
      other is RetentionPolicy && other.days == days;

  @override
  int get hashCode => days.hashCode;

  @override
  String toString() => 'RetentionPolicy($days days)';
}
