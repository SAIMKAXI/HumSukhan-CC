import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/core/env/app_version.dart';

void main() {
  test('the version shown in the app matches pubspec.yaml', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final RegExpMatch? match = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull, reason: 'pubspec.yaml has no version');
    expect(
      AppVersion.current,
      match![1],
      reason:
          'a version the user reads that differs from the version that was '
          'built makes every bug report ambiguous',
    );
  });

  test('the changelog documents the shipped version', () {
    final String changelog = File('CHANGELOG.md').readAsStringSync();
    expect(
      changelog,
      contains('## ${AppVersion.current}'),
      reason: 'a release with no entry is a release nobody can read',
    );
  });
}
