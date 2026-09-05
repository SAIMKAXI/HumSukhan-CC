import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/conversation/conversation.dart';

/// A storage failure.
final class StorageFailure extends Failure {
  /// Creates a storage failure for [code].
  const StorageFailure(
    FailureCode code, {
    super.detail,
    super.isRecoverable = true,
  }) : super(code: code);
}

/// Where saved conversations live.
///
/// Scoped to the signed-in user by the implementation; switching user rebuilds
/// the whole provider tree, so no repository instance is ever shared across
/// accounts.
abstract interface class ConversationRepositoryPort {
  /// Every saved conversation, newest first.
  Future<Result<List<Conversation>, StorageFailure>> list();

  /// Saves [conversation], replacing any with the same id.
  Future<Result<Unit, StorageFailure>> save(Conversation conversation);

  /// Deletes the conversation with [id].
  Future<Result<Unit, StorageFailure>> delete(String id);

  /// Removes conversations older than [retention], returning how many went.
  Future<Result<int, StorageFailure>> purgeExpired(Duration retention);
}
