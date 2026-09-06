# HumSukhan

**هم سخن** — *one who speaks with you.*

An accessibility-first communication assistant for Deaf and hard-of-hearing
people, in English and Urdu.

| Pillar | What it does |
|---|---|
| **Everyday** | Live captions of the person speaking to you, and spoken replies |
| **Professional** | A complete meeting or lecture transcript — pause for the break, resume into the same one — then a summary with action items |
| **Environmental** | On-device detection of nine safety-relevant sounds, with haptic and visual alerts |

Speech runs on the device. Install it and it works — no account, no key, no
signal, and nothing to configure.

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
infrastructure/ adapters: device recogniser, platform TTS, language installs,
               sherpa-onnx, Deepgram, Supabase, storage
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
flutter run
```

That is the whole of it. Recognition and speech run on the device, so captions,
the speak button and environmental alerts work on a stock install with nothing
configured — no account, no key, no signal.

A backend adds three things and nothing else: accounts that follow the user
between phones, AI summaries of a session, and a fallback recogniser for a
device that has no model for the user's language and no way to fetch one.

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<publishable key>
```

Without those defines the app signs the user in to a device account rather than
showing a sign-in screen no password can pass, and the features that genuinely
need a server say so with a remedy instead of appearing to work. See
[`supabase/README.md`](supabase/README.md) for the backend.

**No third-party API key ever reaches the device.** Provider credentials live
in Edge Functions, which return either a 60-second recognition token or a
finished result.

## A language the phone does not have

The app never tells anyone to open system settings and find a speech engine.
It detects the gap, explains it in one sentence, and offers one button; the
device does the download, the app verifies it against the engine itself, and
then carries on with whatever the user was trying to do. On Android 13+ a
recognition model downloads in the app, with real progress on 14+; a voice goes
through the engine's own installer, because the platform provides no
in-process API for it, and the app re-checks on resume.

Where a device offers no guided install, that is said plainly rather than
rendered as a button that opens nothing.

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
