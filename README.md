# HumSukhan

**هم سخن** — *one who speaks with you.*

An accessibility-first communication assistant for Deaf and hard-of-hearing
people, in English and Urdu.

| Pillar | What it does |
|---|---|
| **Everyday** | Live captions of the person speaking to you, and spoken replies |
| **Professional** | A complete meeting or lecture transcript, then a summary with action items |
| **Environmental** | On-device detection of nine safety-relevant sounds, with haptic and visual alerts |

The design constraint that shapes everything: **the user may not be able to
hear failures.** Any state communicated only by sound does not exist. Every
error says what happened and what to do about it, on screen, in the user's
language.

## Architecture

Dependencies point inward, and a test enforces it rather than a document
describing it.

```
core/          tokens, themes, Result/Failure, both languages
domain/        entities and ports — no Flutter, no plugins, no I/O
application/   session state machines and use cases
infrastructure/ adapters: Deepgram, platform TTS, sherpa-onnx, Supabase, storage
features/      one folder per screen, plus the shared design system
composition/   the only place that knows both a port and its adapter
```

`domain` imports nothing from Flutter or any plugin, which is what makes the
whole speech stack testable with no device and no network.
`application/providers.dart` declares the ports the UI watches;
`composition/providers.dart` binds them. A feature cannot name an adapter, let
alone construct one — `test/architecture/layering_test.dart` fails the build if
one tries.

## Running it

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<publishable key>
```

Without those defines the app still builds and runs; recognition and summaries
report that they cannot reach a server, with a remedy, instead of appearing to
work. See [`supabase/README.md`](supabase/README.md) for the backend.

**No third-party API key ever reaches the device.** Provider credentials live
in Edge Functions, which return either a 60-second recognition token or a
finished result.

## Checks

```bash
dart format --set-exit-if-changed lib test integration_test tool
flutter analyze --fatal-infos
flutter test
flutter test test/journeys           # the three journeys, headless
flutter test integration_test        # the same journeys, on a device
```

CI runs the first three plus a debug APK build on every pull request. The
release workflow is tag-driven and refuses to publish unless the tag matches
the version in `pubspec.yaml` and the signed APK exists and is non-empty.

## Documents

- [`docs/instructions.md`](docs/instructions.md) — the experience, the DOs and
  DON'Ts, and §5.1: fifteen defects that reached users, each written as a rule
  with its root cause. **Start there.**
- [`docs/architecture.md`](docs/architecture.md) — why the layering is what it is.
- [`docs/design.md`](docs/design.md) — the interface and the design system.
- [`docs/REGRESSIONS.md`](docs/REGRESSIONS.md) — which regression tests were
  demonstrated to fail on the unfixed code, and which were not.
