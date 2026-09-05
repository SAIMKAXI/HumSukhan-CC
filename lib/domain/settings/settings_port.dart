import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/conversation/conversation_repository_port.dart';
import 'package:humsukhan/domain/settings/app_settings.dart';

/// Where settings are persisted.
///
/// Scoped per user by the implementation: switching account must not carry the
/// previous user's choices across.
abstract interface class SettingsPort {
  /// Loads the stored settings, or the defaults when there are none.
  Future<Result<AppSettings, StorageFailure>> load();

  /// Persists [settings].
  Future<Result<Unit, StorageFailure>> save(AppSettings settings);
}
