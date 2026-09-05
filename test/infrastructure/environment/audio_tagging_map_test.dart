import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/domain/environment/sound_event.dart';
import 'package:humsukhan/infrastructure/environment/audio_tagging_map.dart';

/// The index table is only meaningful if it matches the label file that ships
/// in the bundle. This test reads the real asset rather than trusting a comment.
void main() {
  late Map<int, String> labels;

  setUpAll(() {
    labels = <int, String>{};
    final List<String> lines = File('assets/models/ced-tiny-labels.csv')
        .readAsLinesSync();
    for (final String line in lines.skip(1)) {
      final int firstComma = line.indexOf(',');
      if (firstComma < 0) continue;
      final int? index = int.tryParse(line.substring(0, firstComma));
      if (index == null) continue;
      // The display name is the third field and may itself contain commas
      // ("Baby cry, infant cry"), so split on the first two commas only.
      final int secondComma = line.indexOf(',', firstComma + 1);
      if (secondComma < 0) continue;
      labels[index] = line
          .substring(secondComma + 1)
          .replaceAll('"', '')
          .trim();
    }
  });

  test('the shipped label file has the expected 527 AudioSet classes', () {
    expect(labels.length, 527);
  });

  test('every mapped index names the sound it claims to', () {
    AudioTaggingMap.expectedLabels.forEach((int index, String expected) {
      expect(
        labels[index],
        expected,
        reason:
            'AudioSet index $index is not "$expected" in the shipped labels',
      );
    });
  });

  test('every promised sound has at least one index behind it', () {
    for (final SoundKind kind in SoundKind.values) {
      expect(
        AudioTaggingMap.indices[kind],
        isNotEmpty,
        reason: '${kind.name} is offered in the UI with nothing to detect it',
      );
    }
  });

  test('no index is claimed by two different sounds', () {
    final Set<int> seen = <int>{};
    for (final List<int> indices in AudioTaggingMap.indices.values) {
      for (final int index in indices) {
        expect(seen.add(index), isTrue, reason: 'index $index is mapped twice');
      }
    }
  });

  test('the reverse lookup covers every mapped index', () {
    for (final MapEntry<SoundKind, List<int>> entry
        in AudioTaggingMap.indices.entries) {
      for (final int index in entry.value) {
        expect(AudioTaggingMap.byIndex[index], entry.key);
      }
    }
  });

  test('every mapped index exists in the shipped label file', () {
    for (final int index in AudioTaggingMap.byIndex.keys) {
      expect(labels.containsKey(index), isTrue, reason: 'unknown index $index');
    }
  });
}
