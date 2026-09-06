# Regression proofs

> A regression test must be **shown to fail on the unfixed code**. If it cannot
> reproduce the original condition, say so in the test rather than claiming
> coverage you don't have.
> — docs/architecture.md §9

This file records which of those proofs were actually performed for v1.0.0, and
which were not. Each "demonstrated" row was produced by reintroducing the
defect, running the suite, watching it go red, and reverting.

## Demonstrated on reintroduced code

| Bug | The defect, put back | Test that caught it |
|---|---|---|
| **B2** — a pause closed the microphone | `SilenceElapsed` set `closeMicrophone: true` | `turn_policy_test.dart` → *silence commits the draft and leaves the microphone open* |
| **B3** — finals overwrote each other | `FinalReceived` replaced `pendingFinal` instead of appending | `turn_policy_test.dart` → *a second final is appended to the first* |
| **B4** — a dead stream looked alive | `_onSttStreamDone` emptied to `{}` | `conversation_session_test.dart` → *a stream that closes with no terminal event still fails loudly* |
| **B10** — two taps, two microphones | the re-entrancy guard moved to after the first `await` | `conversation_session_test.dart` → *a second start while the first is in flight is ignored* |
| **B12** — a resource that was not there | the five `ic_launcher_monochrome.png` files deleted | `android_manifest_test.dart` → *every adaptive-icon layer has a PNG in every density* |
| **B14** — the recogniser was invisible | the `RecognitionService` `<queries>` entry removed | `android_manifest_test.dart` → *RecognitionService is queryable* |

## Covered, but not proved against the original code

These have tests, and the tests are meaningful. What was not done is
reintroducing the exact shipped defect, because the code it lived in does not
exist in this rewrite — there is no `DeepgramTranscriptionService` singleton to
reach into, and no second `SpeechProvider` to delete.

| Bug | What the test asserts instead |
|---|---|
| **B1** — a stale singleton overwrote every caption | `conversation_session_test.dart` → *each committed caption carries its own text and id*, and *identical captions remain distinct entries*. The session takes every collaborator through its constructor, so there is no global to reach for. Enforced structurally by `layering_test.dart`. |
| **B5** — the capability probe spoke aloud | `native_tts_adapter.dart` answers capability questions with `getLanguages`, which cannot make a sound. There is no synthesis path in the probe to test *against*; the guarantee is that the code does not exist. |
| **B6** — a corrupt model was a permanent trap | `monitoring_controller_test.dart` → *a model that will not load blocks the start with a reason*, and the repository quarantines and reinstalls anything that fails size, checksum or load. Not proved against the original existence-only check, which is not in this codebase. |
| **B7** — five silent early returns | `insight_service_test.dart` → *every failure path changes state*, which walks all five distinct failures and asserts a state change for each. |
| **B8** — a Speak failure was invisible | `conversation_session_test.dart` → *a speak failure is returned rather than thrown*; the adapters return `Result` and have no throwing path to reintroduce. |
| **B9** — a stale negative cache | `SpeechCapabilityService` keys on platform + OS version + engine id + language and expires negatives. Covered by construction; a device is needed to see a real engine change. |
| **B11** — two implementations, tests bound to the dead one | `layering_test.dart` and one port per role. There is no duplicate to point a test at. |
| **B13** — the badge lost its brand green | `BrandLogo` supplies `AppTokens.brandIconBackground` itself and `android_manifest_test.dart` checks the asset ships. Whether it *looks* right is a device check. |
| **B15** — notified after dispose | `conversation_session_test.dart` → *events after dispose change nothing and do not throw*. |

## Defects found while building v1.0.0

Not from the register — these were introduced in this codebase and caught by
its own tests before release. Each has a test that fails without its fix.

| Defect | Found by | Test |
|---|---|---|
| A settings change disposed the live conversation and the running monitor | the Alerts widget suite, when the toggle appeared to do nothing | `provider_lifetime_test.dart` |
| A settings load completing late reverted the user's change | the same investigation | `provider_lifetime_test.dart` |
| Send and Speak stayed disabled while typing English | the Everyday widget suite | `conversation_screen_test.dart` |
| The Professional tab's button could not be tapped | Journey 2, at phone size | `journey_scenarios.dart` |
| One snack bar was shown five times and collided with itself | Journey 2 | `journey_scenarios.dart` |
| The alert card's dismiss button drew but did not respond | Journey 3 | `environment_screen_test.dart` |
| Both Settings language rows threw at phone width | Journey 1 | `journey_scenarios.dart` |
| `WindowBuffer` emitted the same 3-second slice repeatedly | `window_buffer_test.dart` while it was being written | `window_buffer_test.dart` |
