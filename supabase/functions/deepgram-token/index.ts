// Mints a short-lived Deepgram key for one recognition session.
//
// The project's Deepgram API key stays here. The client receives a temporary
// key that expires in seconds, so a stolen token buys a moment, not an account.

import { failure, guardMethod, json, requireUser } from '../_shared/auth.ts';

/** How long a minted key lives. Long enough to connect, short enough to matter. */
const TTL_SECONDS = 60;

Deno.serve(async (request: Request) => {
  const guard = guardMethod(request);
  if (guard) return guard;

  const caller = await requireUser(request);
  if (caller instanceof Response) return caller;

  const apiKey = Deno.env.get('DEEPGRAM_API_KEY');
  const projectId = Deno.env.get('DEEPGRAM_PROJECT_ID');
  if (!apiKey || !projectId) {
    // Say which side is misconfigured. A generic 500 sends the user hunting
    // through their own settings for a server problem.
    return failure('backendUnavailable', 503, 'recognition is not configured');
  }

  try {
    const response = await fetch(
      `https://api.deepgram.com/v1/projects/${projectId}/keys`,
      {
        method: 'POST',
        headers: {
          Authorization: `Token ${apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          comment: `humsukhan session for ${caller.userId}`,
          scopes: ['usage:write'],
          time_to_live_in_seconds: TTL_SECONDS,
          tags: ['humsukhan', 'ephemeral'],
        }),
      },
    );

    if (!response.ok) {
      return failure(
        'sttAuthFailed',
        502,
        `deepgram returned ${response.status}`,
      );
    }

    const body = await response.json();
    if (typeof body?.key !== 'string') {
      return failure('sttAuthFailed', 502, 'no key in the provider response');
    }

    return json({ token: body.key, expires_in: TTL_SECONDS });
  } catch (error) {
    return failure('network', 502, `${error}`);
  }
});
