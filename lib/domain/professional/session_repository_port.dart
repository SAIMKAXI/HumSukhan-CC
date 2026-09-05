import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/conversation/conversation_repository_port.dart';
import 'package:humsukhan/domain/professional/professional_session.dart';

/// Where Professional sessions live.
abstract interface class SessionRepositoryPort {
  /// Every session, newest first.
  Future<Result<List<ProfessionalSession>, StorageFailure>> list();

  /// One session by [id].
  Future<Result<ProfessionalSession?, StorageFailure>> find(String id);

  /// Saves [session], replacing any with the same id.
  Future<Result<Unit, StorageFailure>> save(ProfessionalSession session);

  /// Deletes the session with [id].
  Future<Result<Unit, StorageFailure>> delete(String id);

  /// Removes sessions past their own retention, returning how many went.
  Future<Result<int, StorageFailure>> purgeExpired(DateTime now);
}
