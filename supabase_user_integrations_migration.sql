-- ============================================================================
-- CIDAN AI: USER SAVED INTEGRATIONS & CREDENTIALS VAULT MIGRATION
-- Stores verified connections per user email with active selection, editing, and removal
-- Run in Supabase Cloud Dashboard -> SQL Editor (vettckrwudnnvoalvjno)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.user_saved_integrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_email TEXT NOT NULL,
    bank_name TEXT NOT NULL DEFAULT 'Apex Federal Reserve',
    bank_code TEXT NOT NULL DEFAULT 'apex-bank-01',
    integration_name TEXT NOT NULL,
    environment VARCHAR(32) NOT NULL DEFAULT 'PRODUCTION' CHECK (environment IN ('DEVELOPMENT', 'UAT', 'PRODUCTION')),
    source_type VARCHAR(32) NOT NULL, -- 'REST_API', 'GRAPHQL', 'POSTGRESQL', 'MYSQL', 'MONGODB', 'REDIS'
    config_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    credential_ref TEXT, -- Encrypted / Vault password, token, or API key
    ssl_config JSONB NOT NULL DEFAULT '{"enabled": true, "verify_cert": true}'::jsonb,
    status VARCHAR(32) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'PENDING', 'FAILED', 'VERIFIED')),
    is_selected BOOLEAN NOT NULL DEFAULT true, -- Active connection chosen for rule extraction/processing
    last_verified_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Performance indices for rapid lookups by user email and selection state
CREATE INDEX IF NOT EXISTS idx_user_saved_integrations_email 
    ON public.user_saved_integrations (user_email);

CREATE INDEX IF NOT EXISTS idx_user_saved_integrations_selected 
    ON public.user_saved_integrations (user_email, is_selected);

-- Enable Row Level Security (RLS)
ALTER TABLE public.user_saved_integrations ENABLE ROW LEVEL SECURITY;

-- Allow public access for user_saved_integrations via Supabase Anon Key
DROP POLICY IF EXISTS "Allow public access for user_saved_integrations" ON public.user_saved_integrations;
CREATE POLICY "Allow public access for user_saved_integrations" 
    ON public.user_saved_integrations FOR ALL 
    USING (true) 
    WITH CHECK (true);
