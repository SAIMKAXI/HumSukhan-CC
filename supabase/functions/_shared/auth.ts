// Shared request handling for every Edge Function.
//
// The rule these functions exist to enforce: no third-party API key ever
// reaches the client. Each function holds the provider credential in its own
// environment and returns either a short-lived token or a finished result.

import { createClient, SupabaseClient } from 'jsr:@supabase/supabase-js@2';

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

/** A JSON response with CORS headers. */
export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

/** A failure the client can render. `code` maps to a FailureCode in the app. */
export function failure(code: string, status: number, detail?: string): Response {
  return json({ error: code, detail }, status);
}

/**
 * Resolves the caller, or returns a 401.
 *
 * Every function is authenticated: an unauthenticated caller must never be
 * able to spend the project's provider quota.
 */
export async function requireUser(
  request: Request,
): Promise<{ userId: string; client: SupabaseClient } | Response> {
  const authorization = request.headers.get('Authorization');
  if (!authorization) return failure('authNoSession', 401);

  const client = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: authorization } } },
  );

  const { data, error } = await client.auth.getUser();
  if (error || !data.user) return failure('authNoSession', 401);
  return { userId: data.user.id, client };
}

/** Rejects anything that is not a POST, and answers CORS preflight. */
export function guardMethod(request: Request): Response | null {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (request.method !== 'POST') return failure('invalidInput', 405);
  return null;
}
