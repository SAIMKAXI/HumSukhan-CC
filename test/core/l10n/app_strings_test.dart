import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/l10n/app_language.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';

/// "A string added in English is not done" (docs/instructions.md §3).
///
/// The maps are private to the strings library, so completeness is checked
/// through the public API plus a source scan — a missing Urdu entry falls back
/// to English, which is exactly the silent half-translation this test forbids.
void main() {
  final AppStrings english = AppStrings.of(AppLanguage.english);
  final AppStrings urdu = AppStrings.of(AppLanguage.urdu);

  /// Keys whose translation is legitimately identical in both languages.
  const Set<StringKey> sameInBothLanguages = <StringKey>{};

  test('every key resolves to non-empty copy in English', () {
    for (final StringKey key in StringKey.values) {
      expect(english(key).trim(), isNotEmpty, reason: 'English ${key.name}');
    }
  });

  test('every key resolves to non-empty copy in Urdu', () {
    for (final StringKey key in StringKey.values) {
      expect(urdu(key).trim(), isNotEmpty, reason: 'Urdu ${key.name}');
    }
  });

  test('no key silently falls back to English in Urdu', () {
    final List<String> untranslated = <String>[];
    for (final StringKey key in StringKey.values) {
      if (sameInBothLanguages.contains(key)) continue;
      if (urdu(key) == english(key)) untranslated.add(key.name);
    }
    expect(
      untranslated,
      isEmpty,
      reason: 'these keys have no Urdu translation: $untranslated',
    );
  });

  test('the Urdu table declares an entry for every key', () {
    // Guards against the fallback path hiding a missing entry: the source must
    // literally list every key in the Urdu map.
    final String source = File('lib/core/l10n/app_strings.dart')
        .readAsStringSync();
    final int urduMapStart = source.indexOf(
      'const Map<StringKey, String> _urdu',
    );
    expect(urduMapStart, greaterThan(0));
    final String urduMap = source.substring(
      urduMapStart,
      source.indexOf('};', urduMapStart),
    );
    final List<String> missing = StringKey.values
        .where((StringKey k) => !urduMap.contains('StringKey.${k.name}:'))
        .map((StringKey k) => k.name)
        .toList();
    expect(missing, isEmpty, reason: 'missing from the Urdu table: $missing');
  });

  test('every failure code has a message in both languages', () {
    for (final FailureCode code in FailureCode.values) {
      expect(
        english.failureMessage(code).trim(),
        isNotEmpty,
        reason: 'English ${code.name}',
      );
      expect(
        urdu.failureMessage(code).trim(),
        isNotEmpty,
        reason: 'Urdu ${code.name}',
      );
      expect(
        urdu.failureMessage(code),
        isNot(english.failureMessage(code)),
        reason: 'untranslated failure message: ${code.name}',
      );
    }
  });

  test('a failure with a remedy renders both halves', () {
    const Failure offline = _TestFailure(FailureCode.offline);
    final String described = english.describe(offline);
    expect(described, contains(english.failureMessage(FailureCode.offline)));
    expect(described, contains(english.failureRemedy(FailureCode.offline)!));
  });

  test('a failure with no remedy renders only the message', () {
    const Failure unknown = _TestFailure(FailureCode.unknown);
    expect(
      english.describe(unknown),
      english.failureMessage(FailureCode.unknown),
    );
  });

  test('placeholders are substituted, not printed', () {
    final String greeting = english.format(
      StringKey.homeGreeting,
      <String, String>{'name': 'Sana'},
    );
    expect(greeting, 'Hello, Sana');
    expect(greeting, isNot(contains('{name}')));

    final String urduGreeting = urdu.format(
      StringKey.homeGreeting,
      <String, String>{'name': 'ثنا'},
    );
    expect(urduGreeting, isNot(contains('{name}')));
    expect(urduGreeting, contains('ثنا'));
  });

  test('no internal mode name reaches user-facing copy', () {
    // `Auto` and `none` are internal names and must never be shown
    // (design.md §9, docs/instructions.md §3).
    const List<String> internalNames = <String>[
      'Auto',
      'STTMode',
      'sherpaBatch',
      'null',
      'undetermined',
    ];
    for (final StringKey key in StringKey.values) {
      for (final String internal in internalNames) {
        expect(
          english(key),
          isNot(contains(internal)),
          reason: '${key.name} leaks the internal name "$internal"',
        );
      }
    }
  });
}

final class _TestFailure extends Failure {
  const _TestFailure(FailureCode code) : super(code: code);
}
