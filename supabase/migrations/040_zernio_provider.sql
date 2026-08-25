-- BBIS WACRM — Zernio provider bridge
SET search_path TO bbis_wacrm, public, extensions;

ALTER TABLE conversations
  ADD COLUMN IF NOT EXISTS provider TEXT NOT NULL DEFAULT 'zernio',
  ADD COLUMN IF NOT EXISTS provider_conversation_id TEXT,
  ADD COLUMN IF NOT EXISTS provider_account_id TEXT;

ALTER TABLE contacts
  ADD COLUMN IF NOT EXISTS provider_contact_id TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_conversations_provider_external
  ON conversations(account_id, provider, provider_conversation_id)
  WHERE provider_conversation_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS channel_integrations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  provider TEXT NOT NULL DEFAULT 'zernio' CHECK (provider IN ('zernio')),
  provider_account_id TEXT,
  provider_profile_id TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive','error')),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(account_id, provider)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_channel_integrations_provider_account
  ON channel_integrations(provider, provider_account_id)
  WHERE provider_account_id IS NOT NULL;

ALTER TABLE channel_integrations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS channel_integrations_select ON channel_integrations;
DROP POLICY IF EXISTS channel_integrations_modify ON channel_integrations;
CREATE POLICY channel_integrations_select ON channel_integrations
  FOR SELECT USING (is_account_member(account_id, 'viewer'));
CREATE POLICY channel_integrations_modify ON channel_integrations
  FOR ALL USING (is_account_member(account_id, 'admin'))
  WITH CHECK (is_account_member(account_id, 'admin'));

CREATE TABLE IF NOT EXISTS provider_webhook_events (
  id TEXT PRIMARY KEY,
  provider TEXT NOT NULL DEFAULT 'zernio',
  event_type TEXT NOT NULL,
  provider_account_id TEXT,
  account_id UUID REFERENCES accounts(id) ON DELETE SET NULL,
  payload JSONB NOT NULL,
  processed BOOLEAN NOT NULL DEFAULT FALSE,
  error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_provider_webhook_events_created
  ON provider_webhook_events(created_at DESC);

ALTER TABLE provider_webhook_events ENABLE ROW LEVEL SECURITY;
-- No authenticated-user policy by design. Service role handles webhook events.

DROP TRIGGER IF EXISTS set_updated_at ON channel_integrations;
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON channel_integrations
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

NOTIFY pgrst, 'reload schema';
