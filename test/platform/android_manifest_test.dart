import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/infrastructure/speech/platform_speech_installer.dart';

/// Manifest configuration is reviewed code.
///
/// Two shipped defects live here: a `<monochrome>` layer that referenced a
/// drawable nobody added, which broke every release build at resource linking
/// (B12), and a missing `<queries>` entry that made the device recogniser
/// invisible to the app on Android 11+ (B14).
void main() {
  final String manifest = File('android/app/src/main/AndroidManifest.xml')
      .readAsStringSync();
  final Directory res = Directory('android/app/src/main/res');

  const List<String> densities = <String>[
    'mipmap-mdpi',
    'mipmap-hdpi',
    'mipmap-xhdpi',
    'mipmap-xxhdpi',
    'mipmap-xxxhdpi',
  ];

  group('permissions', () {
    for (final String permission in <String>[
      'android.permission.RECORD_AUDIO',
      'android.permission.FOREGROUND_SERVICE',
      'android.permission.FOREGROUND_SERVICE_MICROPHONE',
      'android.permission.POST_NOTIFICATIONS',
      'android.permission.VIBRATE',
      'android.permission.INTERNET',
    ]) {
      test('$permission is declared', () {
        expect(manifest, contains('android:name="$permission"'));
      });
    }
  });

  group('B14 — every service resolved at runtime is declared', () {
    test('TTS_SERVICE is queryable', () {
      expect(
        manifest,
        contains('<action android:name="android.intent.action.TTS_SERVICE"/>'),
      );
    });

    test('RecognitionService is queryable', () {
      expect(
        manifest,
        contains('<action android:name="android.speech.RecognitionService"/>'),
        reason:
            'without this the device recogniser is invisible on Android 11+',
      );
    });

    test('the voice installer is queryable', () {
      expect(
        manifest,
        contains(
          '<action android:name="android.speech.tts.engine.INSTALL_TTS_DATA"/>',
        ),
        reason:
            'the guided install resolves this before offering the button; '
            'undeclared, a phone that can install a voice looks like one that '
            'cannot',
      );
    });

    test('the recognition intent is queryable', () {
      expect(
        manifest,
        contains(
          '<action android:name="android.speech.action.RECOGNIZE_SPEECH"/>',
        ),
      );
    });

    test('every query sits inside the <queries> block', () {
      final int start = manifest.indexOf('<queries>');
      final int end = manifest.indexOf('</queries>');
      expect(start, greaterThan(0));
      final String queries = manifest.substring(start, end);
      expect(queries, contains('TTS_SERVICE'));
      expect(queries, contains('android.speech.RecognitionService'));
      expect(queries, contains('INSTALL_TTS_DATA'));
      expect(queries, contains('RECOGNIZE_SPEECH'));
    });
  });

  group('foreground service', () {
    test('the monitoring service declares the microphone type', () {
      expect(
        manifest,
        contains('android:foregroundServiceType="microphone"'),
        reason: 'Android 14+ throws without a declared type',
      );
    });

    test('the Quick Settings tile is declared with its permission', () {
      expect(manifest, contains('MonitoringTileService'));
      expect(manifest, contains('android.permission.BIND_QUICK_SETTINGS_TILE'));
      expect(
        manifest,
        contains('android.service.quicksettings.action.QS_TILE'),
      );
    });

    test('the tile service class exists', () {
      expect(
        File(
          'android/app/src/main/kotlin/pk/humsukhan/humsukhan/'
          'MonitoringTileService.kt',
        ).existsSync(),
        isTrue,
      );
    });
  });

  group('the language installer is wired to the platform', () {
    final File plugin = File(
      'android/app/src/main/kotlin/pk/humsukhan/humsukhan/'
      'SpeechInstallPlugin.kt',
    );

    test('the plugin class exists', () {
      expect(plugin.existsSync(), isTrue);
    });

    test('MainActivity registers both channels', () {
      final String activity = File(
        'android/app/src/main/kotlin/pk/humsukhan/humsukhan/MainActivity.kt',
      ).readAsStringSync();

      // A channel the Dart side calls and the platform never registers fails
      // as MissingPluginException — which the installer reports as "no guided
      // install", silently turning a working phone into an unsupported one.
      expect(activity, contains('SpeechInstallPlugin.METHOD_CHANNEL'));
      expect(activity, contains('SpeechInstallPlugin.EVENT_CHANNEL'));
    });

    test('the channel names match the ones Dart calls', () {
      final String kotlin = plugin.readAsStringSync();

      expect(
        kotlin,
        contains('"${PlatformSpeechInstaller.methodChannelName}"'),
      );
      expect(kotlin, contains('"${PlatformSpeechInstaller.eventChannelName}"'));
    });

    test('the API 34 listener is reached only behind a version check', () {
      final String kotlin = plugin.readAsStringSync();

      // ModelDownloadListener does not exist before API 34. Building it inside
      // a method older devices load is how a branch that never runs still
      // fails verification.
      expect(kotlin, contains('private object ProgressDownload'));
      final int guard = kotlin.indexOf('UPSIDE_DOWN_CAKE');
      final int use = kotlin.indexOf('ProgressDownload.start');
      expect(guard, greaterThan(0));
      expect(use, greaterThan(guard));
    });
  });

  group('B12 — nothing references a resource that is not there', () {
    /// Whether `@<kind>/<name>` resolves anywhere under res/.
    bool resolves(String kind, String name) {
      for (final FileSystemEntity dir in res.listSync()) {
        if (dir is! Directory) continue;
        final String base = dir.path;
        if (kind == 'mipmap' || kind == 'drawable') {
          if (File('$base/$name.png').existsSync() ||
              File('$base/$name.xml').existsSync() ||
              File('$base/$name.webp').existsSync()) {
            return true;
          }
        } else {
          final File values = File(
            '$base/${kind == 'string' ? 'strings' : 'styles'}.xml',
          );
          if (values.existsSync() &&
              values.readAsStringSync().contains('name="$name"')) {
            return true;
          }
        }
      }
      return false;
    }

    test('every resource the manifest names exists', () {
      final RegExp reference = RegExp(
        r'@(mipmap|drawable|string|style)/([A-Za-z0-9_]+)',
      );
      final List<String> missing = <String>[];
      for (final RegExpMatch match in reference.allMatches(manifest)) {
        if (!resolves(match[1]!, match[2]!)) {
          missing.add('@${match[1]}/${match[2]}');
        }
      }
      expect(missing, isEmpty, reason: 'manifest references: $missing');
    });

    test('the adaptive icon declares all three layers', () {
      final File icon = File(
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
      );
      expect(icon.existsSync(), isTrue);
      final String xml = icon.readAsStringSync();
      expect(xml, contains('<background'));
      expect(xml, contains('<foreground'));
      expect(
        xml,
        contains('<monochrome'),
        reason: 'a themed-icon launcher needs the monochrome layer',
      );
    });

    test('every adaptive-icon layer has a PNG in every density', () {
      final String xml = File(
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
      ).readAsStringSync();
      final List<String> missing = <String>[];
      for (final RegExpMatch match in RegExp(
        r'@mipmap/([A-Za-z0-9_]+)',
      ).allMatches(xml)) {
        for (final String density in densities) {
          final String path =
              'android/app/src/main/res/$density/${match[1]}.png';
          if (!File(path).existsSync()) missing.add(path);
        }
      }
      expect(missing, isEmpty, reason: 'missing icon layers: $missing');
    });

    test('the in-app badge asset the code names is bundled', () {
      // BrandLogo points at this exact path; shipping without it is the same
      // class of defect as the missing monochrome drawable.
      expect(File('assets/images/icon_mark.png').existsSync(), isTrue);
    });

    test('every asset directory the pubspec declares exists', () {
      final String pubspec = File('pubspec.yaml').readAsStringSync();
      final List<String> missing = <String>[];
      for (final RegExpMatch match in RegExp(
        r'^\s+- (assets/[^\s]+)$',
        multiLine: true,
      ).allMatches(pubspec)) {
        final String path = match[1]!;
        final bool exists = path.endsWith('/')
            ? Directory(path).existsSync()
            : File(path).existsSync();
        if (!exists) missing.add(path);
      }
      expect(missing, isEmpty, reason: 'pubspec declares: $missing');
    });

    test('every font file the pubspec declares exists', () {
      final String pubspec = File('pubspec.yaml').readAsStringSync();
      final List<String> missing = <String>[];
      for (final RegExpMatch match in RegExp(
        r'asset: (assets/fonts/[^\s]+)',
      ).allMatches(pubspec)) {
        if (!File(match[1]!).existsSync()) missing.add(match[1]!);
      }
      expect(missing, isEmpty, reason: 'pubspec declares: $missing');
    });
  });

  group('localisation', () {
    test('Android strings exist in both languages', () {
      final File english = File('android/app/src/main/res/values/strings.xml');
      final File urdu = File('android/app/src/main/res/values-ur/strings.xml');
      expect(english.existsSync(), isTrue);
      expect(urdu.existsSync(), isTrue);

      final RegExp name = RegExp('name="([A-Za-z0-9_]+)"');
      final Set<String> englishNames = name
          .allMatches(english.readAsStringSync())
          .map((RegExpMatch m) => m[1]!)
          .toSet();
      final Set<String> urduNames = name
          .allMatches(urdu.readAsStringSync())
          .map((RegExpMatch m) => m[1]!)
          .toSet();
      expect(
        englishNames.difference(urduNames),
        isEmpty,
        reason: 'an English string with no Urdu is not done',
      );
    });

    test('iOS declares its microphone usage in words a user can act on', () {
      final String plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('NSMicrophoneUsageDescription'));
      expect(plist, contains('on this device'));
    });
  });
}
