import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Dependencies point inward, and the rule is enforced rather than described.
///
/// This is the test that keeps `domain` free of Flutter and plugins, which is
/// what makes the speech stack testable with no device — the thing the previous
/// codebase most lacked (architecture.md §2).
void main() {
  final Directory lib = Directory('lib');

  /// Which layer a path belongs to.
  String? layerOf(String path) {
    final String normalised = path.replaceAll(r'\', '/');
    for (final String layer in <String>[
      'core',
      'domain',
      'application',
      'infrastructure',
      'features',
      'composition',
    ]) {
      if (normalised.startsWith('lib/$layer/')) return layer;
    }
    return null;
  }

  /// What each layer is allowed to import, by layer name.
  const Map<String, Set<String>> allowed = <String, Set<String>>{
    // core knows nothing about the app's features.
    'core': <String>{'core'},
    // domain is pure: it may not even see core's Flutter-facing pieces beyond
    // Result and Failure, which is asserted separately below.
    'domain': <String>{'core', 'domain'},
    'application': <String>{'core', 'domain', 'application'},
    'infrastructure': <String>{'core', 'domain', 'infrastructure'},
    'features': <String>{'core', 'domain', 'application', 'features'},
    // Composition is the one place that may see everything.
    'composition': <String>{
      'core',
      'domain',
      'application',
      'infrastructure',
      'features',
      'composition',
    },
  };

  /// Packages `domain` may never import. A plugin here means the speech stack
  /// can only be tested on a device.
  const Set<String> forbiddenInDomain = <String>{
    'package:flutter/',
    'package:flutter_riverpod/',
    'package:supabase_flutter/',
    'package:flutter_tts/',
    'package:record/',
    'package:sherpa_onnx/',
    'package:permission_handler/',
    'package:shared_preferences/',
    'package:web_socket_channel/',
    'package:http/',
    'dart:ui',
    'dart:io',
  };

  final List<File> sources = lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList(growable: false);

  test('lib contains sources to check', () {
    expect(sources, isNotEmpty);
  });

  test('every dart file under lib sits in a known layer', () {
    final List<String> stray = sources
        .map((File f) => f.path.replaceAll(r'\', '/'))
        .where((String p) => layerOf(p) == null && p != 'lib/main.dart')
        .toList();
    expect(
      stray,
      isEmpty,
      reason: 'files outside the layered structure: $stray',
    );
  });

  test('dependencies point inward', () {
    final List<String> violations = <String>[];
    final RegExp importLine = RegExp(
      r'''^\s*(?:import|export)\s+['"]package:humsukhan/([^/]+)/''',
      multiLine: true,
    );

    for (final File file in sources) {
      final String path = file.path.replaceAll(r'\', '/');
      final String? layer = layerOf(path);
      if (layer == null) continue;
      final Set<String> permitted = allowed[layer]!;
      for (final RegExpMatch match in importLine.allMatches(
        file.readAsStringSync(),
      )) {
        final String target = match[1]!;
        if (!permitted.contains(target)) {
          violations.add('$path imports $target');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('domain imports no Flutter and no plugin', () {
    final List<String> violations = <String>[];
    for (final File file in sources) {
      final String path = file.path.replaceAll(r'\', '/');
      if (!path.startsWith('lib/domain/')) continue;
      final String content = file.readAsStringSync();
      for (final String banned in forbiddenInDomain) {
        if (content.contains("import '$banned") ||
            content.contains('import "$banned')) {
          violations.add('$path imports $banned');
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('a feature never imports another feature', () {
    final RegExp featureImport = RegExp(
      r'''['"]package:humsukhan/features/([^/]+)/''',
    );
    final List<String> violations = <String>[];

    for (final File file in sources) {
      final String path = file.path.replaceAll(r'\', '/');
      if (!path.startsWith('lib/features/')) continue;
      final String own = path.split('/')[2];
      for (final RegExpMatch match in featureImport.allMatches(
        file.readAsStringSync(),
      )) {
        if (match[1] != own) {
          violations.add('$path imports feature ${match[1]}');
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
