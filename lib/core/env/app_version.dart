/// The shipped version, in one place.
///
/// The release workflow asserts the git tag matches `pubspec.yaml`, and
/// `test/core/env/app_version_test.dart` asserts this constant matches it too.
/// A version the user reads that differs from the version that was built makes
/// every bug report ambiguous.
abstract final class AppVersion {
  /// Semantic version, without the build number.
  static const String current = '1.0.0';
}
