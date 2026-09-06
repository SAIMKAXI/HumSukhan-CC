// Speaks text for devices whose platform engine has no voice for the language.
//
// This is the fallback behind FallbackTtsAdapter: the app tries the platform
// engine first, because it is instant and offline, and only reaches here when
// there is no installed voice — which for Urdu is common.

import { failure, guardMethod, json, requireUser } from '../_shared/auth.ts';

/** Longer than this is not a reply, and is refused rather than truncated. */
const MAX_CHARS = 2000;

/** Voices by language. Urdu is served by a multilingual voice, never Hindi. */
const VOICES: Record<string, string> = {
  en: 'aura-asteria-en',
  ur: 'aura-2-multilingual',
};

Deno.serve(async (request: Request) => {
  const guard = guardMethod(request);
  if (guard) return guard;

  const caller = await requireUser(request);
  if (caller instanceof Response) return caller;

  const apiKey = Deno.env.get('DEEPGRAM_API_KEY');
  if (!apiKey) {
    return failure('ttsUnavailable', 503, 'cloud speech is not configured');
  }

  let payload: { text?: unknown; language?: unknown };
  try {
    payload = await request.json();
  } catch (_error) {
    return failure('invalidInput', 400, 'body was not JSON');
  }

  const text = typeof payload.text === 'string' ? payload.text.trim() : '';
  if (text.length === 0) return failure('invalidInput', 400, 'no text');
  if (text.length > MAX_CHARS) {
    return failure('invalidInput', 413, 'text is too long to speak');
  }

  const language = typeof payload.language === 'string'
    ? payload.language.slice(0, 2).toLowerCase()
    : 'en';
  const voice = VOICES[language] ?? VOICES.en;

  try {
    const response = await fetch(
      `https://api.deepgram.com/v1/speak?model=${voice}&encoding=mp3`,
      {
        method: 'POST',
        headers: {
          Authorization: `Token ${apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ text }),
      },
    );

    if (!response.ok) {
      return failure('ttsFailed', 502, `provider returned ${response.status}`);
    }

    const audio = new Uint8Array(await response.arrayBuffer());
    // Base64 rather than a binary body: the client decodes it straight into a
    // player, and the Edge Function contract stays JSON everywhere.
    let binary = '';
    for (const byte of audio) binary += String.fromCharCode(byte);
    return json({ audio: btoa(binary), format: 'mp3' });
  } catch (error) {
    return failure('network', 502, `${error}`);
  }
});
