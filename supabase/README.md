# Backend

Three Edge Functions and one schema. Everything here exists to keep a
third-party credential off the device.

## Functions

| Function | What it does | Secret it holds |
|---|---|---|
| `deepgram-token` | Mints a 60-second recognition key for one session | `DEEPGRAM_API_KEY` |
| `summarise-session` | Turns a transcript into a summary and action items | `ANTHROPIC_API_KEY` |
| `synthesise-speech` | Speaks text when the device has no voice for the language | `DEEPGRAM_API_KEY` |

Every one requires a signed-in caller: an unauthenticated request must never
be able to spend the project's quota.

## Deploying

```bash
supabase link --project-ref <ref>
supabase db push
supabase secrets set DEEPGRAM_API_KEY=... DEEPGRAM_PROJECT_ID=... ANTHROPIC_API_KEY=...
supabase functions deploy deepgram-token summarise-session synthesise-speech
```

Then build the app with the project's URL and publishable key:

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<publishable key>
```

Those two are safe on a device — they are useless without the row-level
security policies in `migrations/`. No other credential is ever passed to the
client, and the app has no code path that would accept one.

## Row-level security

Every table has RLS enabled and a policy scoping rows to `auth.uid()`. The
client's per-user scoping is a convenience; this is the enforcement. Retention
is capped at 15 days by a check constraint as well as by the app, and
`purge_expired()` deletes expired rows server-side so material disappears even
if the user never opens the app again.
