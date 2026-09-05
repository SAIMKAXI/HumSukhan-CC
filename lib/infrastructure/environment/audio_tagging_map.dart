import 'package:humsukhan/domain/environment/sound_event.dart';

/// Maps AudioSet class indices to the nine sounds HumSukhan promises.
///
/// CED-Tiny predicts 527 AudioSet classes; only these matter here. The table is
/// data, not logic, so it is checked by a unit test against the shipped label
/// file rather than trusted.
abstract final class AudioTaggingMap {
  /// AudioSet indices for each [SoundKind].
  static const Map<SoundKind, List<int>> indices = <SoundKind, List<int>>{
    SoundKind.siren: <int>[
      323, // Police car (siren)
      324, // Ambulance (siren)
      325, // Fire engine, fire truck (siren)
      396, // Siren
      397, // Civil defense siren
    ],
    SoundKind.alarm: <int>[
      310, // Car alarm
      388, // Alarm
      395, // Alarm clock
      398, // Buzzer
      399, // Smoke detector, smoke alarm
      400, // Fire alarm
    ],
    SoundKind.glassBreak: <int>[
      441, // Glass
      443, // Shatter
      470, // Breaking
    ],
    SoundKind.doorbell: <int>[
      355, // Doorbell
    ],
    SoundKind.knock: <int>[
      359, // Knock
    ],
    SoundKind.babyCry: <int>[
      23, // Baby cry, infant cry
    ],
    SoundKind.dogBark: <int>[
      74, // Dog
      75, // Bark
      77, // Howl
    ],
    SoundKind.vehicleHorn: <int>[
      308, // Vehicle horn, car horn, honking
      318, // Air horn, truck horn
      331, // Train horn
    ],
    SoundKind.phone: <int>[
      389, // Telephone
      390, // Telephone bell ringing
      391, // Ringtone
    ],
  };

  /// The [SoundKind] for an AudioSet index, or `null` when it is not one of
  /// ours. Built once; the reverse lookup runs on every analysis window.
  static final Map<int, SoundKind> byIndex = <int, SoundKind>{
    for (final MapEntry<SoundKind, List<int>> entry in indices.entries)
      for (final int index in entry.value) index: entry.key,
  };

  /// The names those indices carry in the shipped label file, for the test that
  /// keeps this table honest.
  static const Map<int, String> expectedLabels = <int, String>{
    23: 'Baby cry, infant cry',
    74: 'Dog',
    75: 'Bark',
    77: 'Howl',
    308: 'Vehicle horn, car horn, honking',
    310: 'Car alarm',
    318: 'Air horn, truck horn',
    323: 'Police car (siren)',
    324: 'Ambulance (siren)',
    325: 'Fire engine, fire truck (siren)',
    331: 'Train horn',
    355: 'Doorbell',
    359: 'Knock',
    388: 'Alarm',
    389: 'Telephone',
    390: 'Telephone bell ringing',
    391: 'Ringtone',
    395: 'Alarm clock',
    396: 'Siren',
    397: 'Civil defense siren',
    398: 'Buzzer',
    399: 'Smoke detector, smoke alarm',
    400: 'Fire alarm',
    441: 'Glass',
    443: 'Shatter',
    470: 'Breaking',
  };
}
