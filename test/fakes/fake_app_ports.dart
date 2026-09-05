import 'dart:async';

import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/account/account.dart';
import 'package:humsukhan/domain/account/auth_port.dart';
import 'package:humsukhan/domain/conversation/conversation.dart';
import 'package:humsukhan/domain/conversation/conversation_repository_port.dart';
import 'package:humsukhan/domain/environment/alert_presenter_port.dart';
import 'package:humsukhan/domain/environment/detection_policy.dart';
import 'package:humsukhan/domain/environment/detector_port.dart';
import 'package:humsukhan/domain/environment/model_state.dart';
import 'package:humsukhan/domain/environment/sound_event.dart';
import 'package:humsukhan/domain/professional/insight.dart';
import 'package:humsukhan/domain/professional/insight_port.dart';
import 'package:humsukhan/domain/professional/professional_session.dart';
import 'package:humsukhan/domain/professional/session_repository_port.dart';
import 'package:humsukhan/domain/settings/app_settings.dart';
import 'package:humsukhan/domain/settings/settings_port.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';

/// A summariser under the test's control.
final class FakeInsightPort implements InsightPort {
  /// Creates a fake summariser.
  FakeInsightPort();

  /// Every transcript it was asked to summarise.
  final List<String> requests = <String>[];

  /// What to return on success.
  Insight result = Insight(
    summary: 'A short meeting about the release.',
    keyPoints: const <String>['Ship on Friday'],
    actionItems: const <ActionItem>[
      ActionItem(description: 'Send the notes', owner: 'Sana'),
    ],
    people: const <String>['Sana'],
    generatedAt: DateTime.utc(2026, 3, 1, 10),
  );

  /// When set, [summarise] fails with this.
  InsightFailure? failure;

  /// How long a summarisation takes.
  Duration delay = Duration.zero;

  @override
  Future<Result<Insight, InsightFailure>> summarise({
    required String transcript,
    required LanguageTag language,
  }) async {
    requests.add(transcript);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final InsightFailure? f = failure;
    if (f != null) return Err<Insight, InsightFailure>(f);
    return Ok<Insight, InsightFailure>(result);
  }
}

/// A detector under the test's control.
final class FakeSoundDetector implements SoundDetectorPort {
  /// Creates a fake detector.
  FakeSoundDetector();

  final StreamController<SoundObservation> _observations =
      StreamController<SoundObservation>.broadcast();
  final StreamController<DetectorFailure> _failures =
      StreamController<DetectorFailure>.broadcast();

  /// How many times [start] was called.
  int startCount = 0;

  /// How many times [stop] was called.
  int stopCount = 0;

  /// When set, [start] fails with this.
  DetectorFailure? failOnStart;

  @override
  Stream<SoundObservation> get observations => _observations.stream;

  @override
  Stream<DetectorFailure> get failures => _failures.stream;

  @override
  Future<Result<Unit, DetectorFailure>> start() async {
    startCount++;
    final DetectorFailure? failure = failOnStart;
    if (failure != null) return Err<Unit, DetectorFailure>(failure);
    return const Ok<Unit, DetectorFailure>(unit);
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> dispose() async {
    await _observations.close();
    await _failures.close();
  }

  /// Emits an observation.
  void observe(SoundKind kind, double confidence, DateTime at) {
    if (!_observations.isClosed) {
      _observations.add(
        SoundObservation(kind: kind, confidence: confidence, at: at),
      );
    }
  }

  /// Emits a detector failure.
  void fail(DetectorFailure failure) {
    if (!_failures.isClosed) _failures.add(failure);
  }

  /// Closes the observation stream with no warning.
  Future<void> die() => _observations.close();
}

/// A model repository under the test's control.
final class FakeModelRepository implements ModelRepositoryPort {
  /// Creates a fake repository, ready by default.
  FakeModelRepository({ModelState? initial})
    : _current = initial ?? const ModelReady('/fake/model.onnx');

  final StreamController<ModelState> _states =
      StreamController<ModelState>.broadcast();

  ModelState _current;

  /// What [ensureReady] should resolve to.
  ModelState? nextState;

  /// How many times [ensureReady] was called.
  int ensureCount = 0;

  /// How many times [quarantine] was called.
  int quarantineCount = 0;

  @override
  ModelState get current => _current;

  @override
  Stream<ModelState> get state => _states.stream;

  @override
  Future<ModelState> ensureReady() async {
    ensureCount++;
    final ModelState next = nextState ?? _current;
    _current = next;
    if (!_states.isClosed) _states.add(next);
    return next;
  }

  @override
  Future<void> quarantine() async {
    quarantineCount++;
    _current = const ModelAbsent();
  }

  /// Closes the state stream.
  Future<void> dispose() => _states.close();
}

/// Records what alerts were raised, and through which channels.
final class RecordingAlertPresenter implements AlertPresenterPort {
  /// Creates a recording presenter.
  RecordingAlertPresenter();

  /// Every alert presented, in order.
  final List<SoundEvent> presented = <SoundEvent>[];

  /// The channels each alert used.
  final List<AlertChannels> channels = <AlertChannels>[];

  /// When true, presentation throws — monitoring must survive it.
  bool throwOnPresent = false;

  @override
  Future<void> present(SoundEvent event, AlertChannels channels) async {
    presented.add(event);
    this.channels.add(channels);
    if (throwOnPresent) throw StateError('vibration failed');
  }
}

/// An auth port under the test's control.
final class FakeAuthPort implements AuthPort {
  /// Creates a fake auth port.
  FakeAuthPort();

  final StreamController<AuthEvent> _events =
      StreamController<AuthEvent>.broadcast();

  Account? _account;

  /// A session to restore, when there is one.
  Account? storedSession;

  /// When set, the next call fails with this.
  AuthFailure? nextFailure;

  /// Every password reset requested.
  final List<String> resetRequests = <String>[];

  /// Every password set.
  final List<String> passwordUpdates = <String>[];

  @override
  Account? get currentAccount => _account;

  @override
  Stream<AuthEvent> get events => _events.stream;

  @override
  Future<Result<Account?, AuthFailure>> restore() async {
    final AuthFailure? failure = _take();
    if (failure != null) return Err<Account?, AuthFailure>(failure);
    _account = storedSession;
    return Ok<Account?, AuthFailure>(_account);
  }

  @override
  Future<Result<Account, AuthFailure>> signIn({
    required String email,
    required String password,
  }) async {
    final AuthFailure? failure = _take();
    if (failure != null) return Err<Account, AuthFailure>(failure);
    _account = Account(id: 'user-$email', email: email);
    return Ok<Account, AuthFailure>(_account!);
  }

  @override
  Future<Result<Account, AuthFailure>> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final AuthFailure? failure = _take();
    if (failure != null) return Err<Account, AuthFailure>(failure);
    _account = Account(
      id: 'user-$email',
      email: email,
      displayName: displayName,
    );
    return Ok<Account, AuthFailure>(_account!);
  }

  @override
  Future<Result<Unit, AuthFailure>> signOut() async {
    final AuthFailure? failure = _take();
    if (failure != null) return Err<Unit, AuthFailure>(failure);
    _account = null;
    return const Ok<Unit, AuthFailure>(unit);
  }

  @override
  Future<Result<Unit, AuthFailure>> sendPasswordReset(String email) async {
    resetRequests.add(email);
    final AuthFailure? failure = _take();
    if (failure != null) return Err<Unit, AuthFailure>(failure);
    return const Ok<Unit, AuthFailure>(unit);
  }

  @override
  Future<Result<Unit, AuthFailure>> updatePassword(String password) async {
    passwordUpdates.add(password);
    final AuthFailure? failure = _take();
    if (failure != null) return Err<Unit, AuthFailure>(failure);
    return const Ok<Unit, AuthFailure>(unit);
  }

  @override
  Future<Result<Account, AuthFailure>> updateDisplayName(
    String displayName,
  ) async {
    final AuthFailure? failure = _take();
    if (failure != null) return Err<Account, AuthFailure>(failure);
    final Account? current = _account;
    if (current == null) {
      return const Err<Account, AuthFailure>(
        AuthFailure(FailureCode.authNoSession),
      );
    }
    _account = current.withDisplayName(displayName);
    return Ok<Account, AuthFailure>(_account!);
  }

  /// Pushes a session event, as the backend would.
  void emit(AuthEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  /// Closes the event stream.
  Future<void> dispose() => _events.close();

  AuthFailure? _take() {
    final AuthFailure? failure = nextFailure;
    nextFailure = null;
    return failure;
  }
}

/// In-memory settings.
final class FakeSettingsPort implements SettingsPort {
  /// Creates a fake store.
  FakeSettingsPort({AppSettings? initial}) : _stored = initial;

  AppSettings? _stored;

  /// When set, [save] fails with this.
  StorageFailure? failOnSave;

  /// When set, [load] fails with this.
  StorageFailure? failOnLoad;

  /// Everything that was saved, in order.
  final List<AppSettings> saves = <AppSettings>[];

  @override
  Future<Result<AppSettings, StorageFailure>> load() async {
    final StorageFailure? failure = failOnLoad;
    if (failure != null) return Err<AppSettings, StorageFailure>(failure);
    return Ok<AppSettings, StorageFailure>(_stored ?? const AppSettings());
  }

  @override
  Future<Result<Unit, StorageFailure>> save(AppSettings settings) async {
    saves.add(settings);
    final StorageFailure? failure = failOnSave;
    if (failure != null) return Err<Unit, StorageFailure>(failure);
    _stored = settings;
    return const Ok<Unit, StorageFailure>(unit);
  }
}

/// In-memory conversations.
final class FakeConversationRepository implements ConversationRepositoryPort {
  /// Creates an empty repository.
  FakeConversationRepository();

  final List<Conversation> _items = <Conversation>[];

  /// When set, every call fails with this.
  StorageFailure? failure;

  @override
  Future<Result<List<Conversation>, StorageFailure>> list() async {
    final StorageFailure? f = failure;
    if (f != null) return Err<List<Conversation>, StorageFailure>(f);
    return Ok<List<Conversation>, StorageFailure>(
      List<Conversation>.unmodifiable(_items),
    );
  }

  @override
  Future<Result<Unit, StorageFailure>> save(Conversation conversation) async {
    final StorageFailure? f = failure;
    if (f != null) return Err<Unit, StorageFailure>(f);
    _items
      ..removeWhere((Conversation c) => c.id == conversation.id)
      ..insert(0, conversation);
    return const Ok<Unit, StorageFailure>(unit);
  }

  @override
  Future<Result<Unit, StorageFailure>> delete(String id) async {
    final StorageFailure? f = failure;
    if (f != null) return Err<Unit, StorageFailure>(f);
    _items.removeWhere((Conversation c) => c.id == id);
    return const Ok<Unit, StorageFailure>(unit);
  }

  @override
  Future<Result<int, StorageFailure>> purgeExpired(Duration retention) async {
    final StorageFailure? f = failure;
    if (f != null) return Err<int, StorageFailure>(f);
    final DateTime cutoff = DateTime.now().subtract(retention);
    final int before = _items.length;
    _items.removeWhere((Conversation c) => c.startedAt.isBefore(cutoff));
    return Ok<int, StorageFailure>(before - _items.length);
  }
}

/// In-memory professional sessions.
final class FakeSessionRepository implements SessionRepositoryPort {
  /// Creates an empty repository.
  FakeSessionRepository();

  final List<ProfessionalSession> _items = <ProfessionalSession>[];

  /// When set, every call fails with this.
  StorageFailure? failure;

  @override
  Future<Result<List<ProfessionalSession>, StorageFailure>> list() async {
    final StorageFailure? f = failure;
    if (f != null) return Err<List<ProfessionalSession>, StorageFailure>(f);
    return Ok<List<ProfessionalSession>, StorageFailure>(
      List<ProfessionalSession>.unmodifiable(_items),
    );
  }

  @override
  Future<Result<ProfessionalSession?, StorageFailure>> find(String id) async {
    final StorageFailure? f = failure;
    if (f != null) return Err<ProfessionalSession?, StorageFailure>(f);
    for (final ProfessionalSession session in _items) {
      if (session.id == id) {
        return Ok<ProfessionalSession?, StorageFailure>(session);
      }
    }
    return const Ok<ProfessionalSession?, StorageFailure>(null);
  }

  @override
  Future<Result<Unit, StorageFailure>> save(ProfessionalSession session) async {
    final StorageFailure? f = failure;
    if (f != null) return Err<Unit, StorageFailure>(f);
    _items
      ..removeWhere((ProfessionalSession s) => s.id == session.id)
      ..insert(0, session);
    return const Ok<Unit, StorageFailure>(unit);
  }

  @override
  Future<Result<Unit, StorageFailure>> delete(String id) async {
    final StorageFailure? f = failure;
    if (f != null) return Err<Unit, StorageFailure>(f);
    _items.removeWhere((ProfessionalSession s) => s.id == id);
    return const Ok<Unit, StorageFailure>(unit);
  }

  @override
  Future<Result<int, StorageFailure>> purgeExpired(DateTime now) async {
    final StorageFailure? f = failure;
    if (f != null) return Err<int, StorageFailure>(f);
    final int before = _items.length;
    _items.removeWhere(
      (ProfessionalSession s) =>
          !s.startedAt.add(Duration(days: s.retentionDays)).isAfter(now),
    );
    return Ok<int, StorageFailure>(before - _items.length);
  }
}
