/// A signed-in user.
final class Account {
  /// Creates an account.
  const Account({
    required this.id,
    required this.email,
    this.displayName,
    this.isLocal = false,
  });

  /// Stable identity, and the key every per-user store is scoped by.
  final String id;

  /// The address used to sign in.
  final String email;

  /// What the user wants to be called, when they have said.
  final String? displayName;

  /// Whether this account exists only on this phone.
  ///
  /// Carried on the entity rather than inferred by each screen, because the
  /// difference is user-visible: there is no signing out of a device account
  /// and no password to reset, and offering either would strand the user.
  final bool isLocal;

  /// The name to greet with, falling back to the local part of the email.
  String get greetingName {
    final String? name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final String local = email.split('@').first;
    return local.isEmpty ? email : local;
  }

  /// A copy with [displayName] replaced.
  Account withDisplayName(String? value) =>
      Account(id: id, email: email, displayName: value, isLocal: isLocal);

  @override
  bool operator ==(Object other) =>
      other is Account &&
      other.id == id &&
      other.email == email &&
      other.displayName == displayName &&
      other.isLocal == isLocal;

  @override
  int get hashCode => Object.hash(id, email, displayName, isLocal);

  @override
  String toString() => 'Account($id, $email)';
}
