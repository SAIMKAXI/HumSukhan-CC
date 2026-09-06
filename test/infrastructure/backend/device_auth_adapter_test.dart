import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/domain/account/account.dart';
import 'package:humsukhan/domain/account/auth_port.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/infrastructure/backend/device_auth_adapter.dart';
import 'package:humsukhan/infrastructure/storage/key_value_store.dart';

import '../../fakes/fake_speech_ports.dart';

/// An in-memory store, optionally broken, so the failure path is reachable.
class _MemoryStore implements KeyValueStore {
  final Map<String, String> values = <String, String>{};
  bool broken = false;

  @override
  Future<String?> read(String key) async {
    if (broken) throw StateError('store unavailable');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (broken) throw StateError('store unavailable');
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  Future<Set<String>> keys() async => values.keys.toSet();
}

void main() {
  late _MemoryStore store;
  late DeviceAuthAdapter adapter;

  setUp(() {
    store = _MemoryStore();
    adapter = DeviceAuthAdapter(store: store, ids: FakeIdGenerator());
  });

  tearDown(() => adapter.dispose());

  test('a first run reaches the app rather than a sign-in wall', () async {
    final Result<Account?, AuthFailure> result = await adapter.restore();

    // The whole reason this adapter exists: without it, a build with no
    // Supabase configuration shows a sign-in screen no password can pass.
    final Account account = result.valueOrNull!;
    expect(account.isLocal, isTrue);
    expect(adapter.currentAccount, isNotNull);
  });

  test(
    'the account id survives a restart, so saved work is still theirs',
    () async {
      final String first = (await adapter.restore()).valueOrNull!.id;

      final DeviceAuthAdapter second = DeviceAuthAdapter(
        store: store,
        ids: FakeIdGenerator(prefix: 'other'),
      );
      addTearDown(second.dispose);
      final String again = (await second.restore()).valueOrNull!.id;

      // A new id each launch would silently orphan every saved conversation
      // behind a scope the user can no longer reach.
      expect(again, first);
    },
  );

  test('restore announces the session so the gate can move on', () async {
    final Future<AuthEvent> event = adapter.events.first;

    await adapter.restore();

    expect(await event, isA<SignedIn>());
  });

  test('the display name is kept, and clearing it is allowed', () async {
    await adapter.restore();

    expect(
      (await adapter.updateDisplayName('Sana')).valueOrNull!.displayName,
      'Sana',
    );
    expect(store.values[DeviceAuthAdapter.nameKey], 'Sana');

    expect(
      (await adapter.updateDisplayName('  ')).valueOrNull!.displayName,
      isNull,
    );
    expect(store.values.containsKey(DeviceAuthAdapter.nameKey), isFalse);
  });

  test('the kept name comes back on the next launch', () async {
    await adapter.restore();
    await adapter.updateDisplayName('Sana');

    final DeviceAuthAdapter second = DeviceAuthAdapter(
      store: store,
      ids: FakeIdGenerator(),
    );
    addTearDown(second.dispose);

    expect((await second.restore()).valueOrNull!.displayName, 'Sana');
  });

  test('signing out is refused rather than faked', () async {
    await adapter.restore();

    final Result<Unit, AuthFailure> result = await adapter.signOut();

    // Succeeding here would strand the user on a sign-in screen for an
    // account that does not exist anywhere to sign in to.
    expect(result.isErr, isTrue);
    expect(result.errorOrNull!.isRecoverable, isFalse);
  });

  test('a password reset is refused, because there is no password', () async {
    await adapter.restore();

    expect((await adapter.sendPasswordReset('x@y.z')).isErr, isTrue);
    expect((await adapter.updatePassword('whatever')).isErr, isTrue);
  });

  test('a broken store fails loudly instead of inventing an account', () async {
    store.broken = true;

    final Result<Account?, AuthFailure> result = await adapter.restore();

    // Carrying on with an invented id would scope this run's data somewhere
    // the next run cannot find.
    expect(result.isErr, isTrue);
    expect(result.errorOrNull!.code, FailureCode.storageReadFailed);
    expect(adapter.currentAccount, isNull);
  });

  test('naming an account that does not exist fails, not throws', () async {
    expect(
      (await adapter.updateDisplayName('Sana')).errorOrNull!.code,
      FailureCode.authNoSession,
    );
  });
}
