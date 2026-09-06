// Summarises a session transcript.
//
// The model provider's key stays here. The client sends a transcript and gets
// back structured JSON it renders with an "AI may be wrong" disclaimer.

import { failure, guardMethod, json, requireUser } from '../_shared/auth.ts';

/** Transcripts longer than this are trimmed to the most recent portion. */
const MAX_TRANSCRIPT_CHARS = 60000;

/** The languages HumSukhan supports. Hindi is never substituted for Urdu. */
const LANGUAGE_NAMES: Record<string, string> = {
  en: 'English',
  ur: 'Urdu (in Urdu script, never Devanagari)',
};

Deno.serve(async (request: Request) => {
  const guard = guardMethod(request);
  if (guard) return guard;

  const caller = await requireUser(request);
  if (caller instanceof Response) return caller;

  const apiKey = Deno.env.get('ANTHROPIC_API_KEY');
  if (!apiKey) {
    return failure('backendUnavailable', 503, 'summaries are not configured');
  }

  let payload: { transcript?: unknown; language?: unknown };
  try {
    payload = await request.json();
  } catch (_error) {
    return failure('invalidInput', 400, 'body was not JSON');
  }

  const transcript =
    typeof payload.transcript === 'string' ? payload.transcript.trim() : '';
  if (transcript.length === 0) {
    return failure('insightTranscriptEmpty', 400);
  }

  const language = typeof payload.language === 'string' ? payload.language : 'en';
  const languageName = LANGUAGE_NAMES[language] ?? LANGUAGE_NAMES.en;
  const trimmed = transcript.length > MAX_TRANSCRIPT_CHARS
    ? transcript.slice(-MAX_TRANSCRIPT_CHARS)
    : transcript;

  const instructions = [
    'You summarise a meeting, lecture or class transcript for a Deaf or',
    'hard-of-hearing reader who could not hear it and is relying entirely on',
    'this summary and the transcript.',
    '',
    `Write every string in ${languageName}.`,
    '',
    'Return only JSON matching this shape, with no prose around it:',
    '{',
    '  "summary": "three to five sentences",',
    '  "key_points": ["..."],',
    '  "action_items": [',
    '    {"description": "...", "owner": "name or null",',
    '     "deadline": "as the transcript expressed it, or null"}',
    '  ],',
    '  "people": ["names mentioned"]',
    '}',
    '',
    'Rules:',
    '- Never invent an action item, an owner or a deadline. Omit what is not',
    '  in the transcript.',
    '- Keep a deadline in the words the transcript used ("before Friday").',
    '- If the transcript is too fragmentary to summarise, return an empty',
    '  summary rather than guessing.',
  ].join('\n');

  try {
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-5',
        max_tokens: 2000,
        system: instructions,
        messages: [{ role: 'user', content: trimmed }],
      }),
    });

    if (!response.ok) {
      return failure(
        'insightGenerationFailed',
        502,
        `model returned ${response.status}`,
      );
    }

    const body = await response.json();
    const text = body?.content?.[0]?.text;
    if (typeof text !== 'string') {
      return failure('insightGenerationFailed', 502, 'no text in the response');
    }

    // The model is asked for bare JSON, but a fenced block is a common and
    // harmless deviation; unwrap it rather than failing the user's request.
    const unfenced = text
      .replace(/^\s*```(?:json)?/i, '')
      .replace(/```\s*$/, '')
      .trim();

    try {
      return json(JSON.parse(unfenced));
    } catch (_error) {
      return failure(
        'insightGenerationFailed',
        502,
        'the model did not return usable JSON',
      );
    }
  } catch (error) {
    return failure('network', 502, `${error}`);
  }
});
