import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/core/time/clock.dart';
import 'package:humsukhan/domain/conversation/conversation_repository_port.dart';
import 'package:humsukhan/domain/professional/session_repository_port.dart';

/// Deletes anything past its retention window.
///
/// Runs on every launch. The countdown shown on a session is a promise, and a
/// promise that only holds while the app happens to be open is not one — the
/// server sweeps too, and neither is trusted as the only enforcement.
final class RetentionSweeper {
  /// Creates a sweeper.
  RetentionSweeper({
    required ConversationRepositoryPort conversations,
    required SessionRepositoryPort sessions,
    required Clock clock,
    AppLogger logger = const SilentLogger(),
  }) : _conversations = conversations,
       _sessions = sessions,
       _clock = clock,
       _logger = logger;

  final ConversationRepositoryPort _conversations;
  final SessionRepositoryPort _sessions;
  final Clock _clock;
  final AppLogger _logger;

  /// Removes expired material, returning how much went.
  ///
  /// Never throws: a sweep that fails must not stop the app from starting, and
  /// it is recorded rather than swallowed.
  Future<int> sweep({required Duration conversationRetention}) async {
    int removed = 0;

    final Result<int, StorageFailure> conversations = await _conversations
        .purgeExpired(conversationRetention);
    removed += conversations.fold((int count) => count, (
      StorageFailure failure,
    ) {
      _logger.log(
        LogLevel.warning,
        'retention',
        'could not purge conversations: $failure',
      );
      return 0;
    });

    final Result<int, StorageFailure> sessions = await _sessions.purgeExpired(
      _clock.now(),
    );
    removed += sessions.fold((int count) => count, (StorageFailure failure) {
      _logger.log(
        LogLevel.warning,
        'retention',
        'could not purge sessions: $failure',
      );
      return 0;
    });

    if (removed > 0) {
      _logger.log(LogLevel.info, 'retention', 'removed $removed expired items');
    }
    return removed;
  }
}
