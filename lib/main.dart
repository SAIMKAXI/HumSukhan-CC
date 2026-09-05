import 'dart:io';

import 'package:flutter/material.dart';
import 'package:humsukhan/composition/providers.dart';
import 'package:humsukhan/core/env/app_config.dart';
import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/composition/shell/humsukhan_app.dart';
import 'package:humsukhan/infrastructure/storage/key_value_store.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show Supabase, SupabaseClient;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const AppLogger logger = DeveloperLogger();
  final AppConfig config = AppConfig.fromEnvironment();

  // Boot-time work that the whole tree depends on. Each step reports its own
  // failure rather than throwing into a splash screen that never resolves.
  final KeyValueStore store = await _openStore(logger);
  final SupabaseClient? client = await _openBackend(config, logger);
  final Directory modelDirectory = await _openModelDirectory(logger);

  runApp(
    HumSukhanScope(
      config: config,
      store: store,
      client: client,
      modelDirectory: modelDirectory,
      child: const HumSukhanApp(),
    ),
  );
}

Future<KeyValueStore> _openStore(AppLogger logger) async {
  try {
    return await PreferencesStore.open();
  } on Object catch (error, stackTrace) {
    // The app still runs; settings simply do not survive a restart, and the
    // Settings screen says so rather than silently forgetting.
    logger.log(
      LogLevel.error,
      'boot',
      'the platform store would not open',
      error: error,
      stackTrace: stackTrace,
    );
    return MemoryStore();
  }
}

Future<SupabaseClient?> _openBackend(AppConfig config, AppLogger logger) async {
  if (!config.hasBackend) {
    logger.log(
      LogLevel.warning,
      'boot',
      'no backend configured; recognition and summaries will report that',
    );
    return null;
  }
  try {
    final Supabase supabase = await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
    );
    return supabase.client;
  } on Object catch (error, stackTrace) {
    logger.log(
      LogLevel.error,
      'boot',
      'the backend would not initialise',
      error: error,
      stackTrace: stackTrace,
    );
    return null;
  }
}

Future<Directory> _openModelDirectory(AppLogger logger) async {
  try {
    final Directory support = await getApplicationSupportDirectory();
    return Directory('${support.path}/models');
  } on Object catch (error, stackTrace) {
    logger.log(
      LogLevel.error,
      'boot',
      'no writable directory for the sound model',
      error: error,
      stackTrace: stackTrace,
    );
    return Directory.systemTemp.createTempSync('humsukhan-models');
  }
}
