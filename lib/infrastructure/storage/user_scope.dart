/// Namespaces every persisted key by the account that owns it.
///
/// Cross-user leakage is prevented structurally: there is no way to build a
/// storage key without saying whose it is, and switching account rebuilds the
/// provider tree with a different scope.
final class UserScope {
  /// Creates a scope for [userId].
  const UserScope(this.userId);

  /// The scope used before anyone signs in — onboarding and app language.
  static const UserScope anonymous = UserScope('anonymous');

  /// The owning account's id.
  final String userId;

  /// The storage key for [name] within this scope.
  String key(String name) => 'humsukhan.$userId.$name';

  @override
  bool operator ==(Object other) =>
      other is UserScope && other.userId == userId;

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() => 'UserScope($userId)';
}
