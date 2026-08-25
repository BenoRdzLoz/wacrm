import { createClient, type SupabaseClient } from '@supabase/supabase-js'

const DB_SCHEMA = process.env.NEXT_PUBLIC_SUPABASE_SCHEMA ?? 'bbis_wacrm'

// Lazy, shared service-role client for automation engine work.
// Mirrors the pattern used by the webhook handler.
let _adminClient: SupabaseClient | null = null

export function supabaseAdmin(): SupabaseClient {
  if (!_adminClient) {
    _adminClient = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!,
      { db: { schema: DB_SCHEMA } },
    )
  }
  return _adminClient
}
