import 'package:shared_preferences/shared_preferences.dart';

/// The persistence primitive every local store is built on.
///
/// An interface rather than `SharedPreferences` directly, so storage behaviour
/// is testable in memory and so exactly one file imports the plugin.
abstract interface class KeyValueStore {
  /// The value for [key], or `null`.
  Future<String?> read(String key);

  /// Stores [value] under [key].
  Future<void> write(String key, String value);

  /// Removes [key].
  Future<void> remove(String key);

  /// Every key currently stored.
  Future<Set<String>> keys();
}

/// [KeyValueStore] over `shared_preferences`.
final class PreferencesStore implements KeyValueStore {
  /// Creates a store over [preferences].
  const PreferencesStore(this._preferences);

  final SharedPreferences _preferences;

  /// Opens the platform store.
  static Future<PreferencesStore> open() async =>
      PreferencesStore(await SharedPreferences.getInstance());

  @override
  Future<String?> read(String key) async => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) async {
    await _preferences.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await _preferences.remove(key);
  }

  @override
  Future<Set<String>> keys() async => _preferences.getKeys();
}

/// In-memory [KeyValueStore]. Used by tests and by a first run that has no
/// platform store yet.
final class MemoryStore implements KeyValueStore {
  /// Creates an empty store.
  MemoryStore([Map<String, String>? initial])
    : _values = <String, String>{...?initial};

  final Map<String, String> _values;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }

  @override
  Future<Set<String>> keys() async => _values.keys.toSet();
}
