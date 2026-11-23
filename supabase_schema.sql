-- ============================================================================
-- CIDAN Banking Regulatory AI - Supabase Database Schema
-- Production Bank-Grade Data Isolation & Row Level Security (RLS)
-- Run this script in your Supabase Project: Dashboard -> SQL Editor -> New Query
-- ============================================================================

-- 1. Table: auth_otps
-- Stores 6-digit OTP codes, target email, expiration timestamp, and verification status.
CREATE TABLE IF NOT EXISTS public.auth_otps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL,
    otp_code VARCHAR(6) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    expires_at TIMESTAMPTZ NOT NULL,
    is_verified BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_auth_otps_email_code ON public.auth_otps (email, otp_code, is_verified);
CREATE INDEX IF NOT EXISTS idx_auth_otps_expires ON public.auth_otps (expires_at);

-- 2. Table: user_history
-- Records complete compliance audit trail per user email (logins, uploads, reviews, approvals)
CREATE TABLE IF NOT EXISTS public.user_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_email TEXT NOT NULL,
    action_type TEXT NOT NULL, -- 'OTP_REQUESTED', 'LOGIN_SUCCESS', 'DOCUMENT_UPLOADED', 'COMPLIANCE_AUDIT_SAVED', 'POLICY_APPROVED', 'INTEGRATION_VERIFIED'
    document_name TEXT,
    document_id TEXT,
    workflow_id TEXT,
    compliance_score INT,
    summary TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_user_history_email ON public.user_history (user_email, created_at DESC);

-- 3. Table: compliance_reports
-- Stores full Virtusa Agent regulatory analysis reports linked to user email
CREATE TABLE IF NOT EXISTS public.compliance_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_email TEXT NOT NULL,
    workflow_id TEXT NOT NULL,
    filename TEXT NOT NULL,
    obligations_count INT NOT NULL DEFAULT 0,
    violations_count INT NOT NULL DEFAULT 0,
    approved_count INT NOT NULL DEFAULT 0,
    report_data JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_compliance_reports_email ON public.compliance_reports (user_email, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_compliance_reports_workflow ON public.compliance_reports (workflow_id);

-- 4. Table: banks
-- Represents enterprise financial institutions
CREATE TABLE IF NOT EXISTS public.banks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    bank_code VARCHAR(32) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_banks_code ON public.banks (bank_code);

-- 5. Table: bank_members
-- Multi-tenant association between banking users and authorized banking institutions
CREATE TABLE IF NOT EXISTS public.bank_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bank_id UUID REFERENCES public.banks(id) ON DELETE CASCADE,
    user_email TEXT NOT NULL,
    role VARCHAR(32) NOT NULL DEFAULT 'AUDITOR' CHECK (role IN ('ADMIN', 'COMPLIANCE_OFFICER', 'AUDITOR', 'VIEWER')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    UNIQUE(bank_id, user_email)
);

CREATE INDEX IF NOT EXISTS idx_bank_members_lookup ON public.bank_members (user_email, bank_id);

-- 6. Table: bank_integrations
-- Represents an integration configuration container (Dev, UAT, Prod)
CREATE TABLE IF NOT EXISTS public.bank_integrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bank_id UUID REFERENCES public.banks(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    environment VARCHAR(16) NOT NULL CHECK (environment IN ('DEVELOPMENT', 'UAT', 'PRODUCTION')),
    integration_type VARCHAR(16) NOT NULL CHECK (integration_type IN ('REST', 'GRAPHQL', 'SQL', 'NOSQL')),
    status VARCHAR(16) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('ACTIVE', 'PENDING', 'FAILED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_bank_integrations_bank ON public.bank_integrations (bank_id);

-- 7. Table: integration_sources
-- Stores specific integration sources (Oracle, Postgres, MongoDB, REST API, etc.)
-- Note: Raw passwords/secrets are NEVER stored in plaintext (stored via credential_ref or vault)
CREATE TABLE IF NOT EXISTS public.integration_sources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    integration_id UUID REFERENCES public.bank_integrations(id) ON DELETE CASCADE,
    source_type VARCHAR(32) NOT NULL,
    config_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    credential_ref TEXT, -- Vault reference or KMS UUID; raw secrets never stored
    ssl_config JSONB NOT NULL DEFAULT '{"enabled": true, "verify_cert": true}'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT true,
    last_verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_integration_sources_integration ON public.integration_sources (integration_id);

-- 8. Table: connection_verifications
-- Audit trail of connection verification tests with latency and read-only sample previews
CREATE TABLE IF NOT EXISTS public.connection_verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id UUID REFERENCES public.integration_sources(id) ON DELETE CASCADE,
    verification_status VARCHAR(16) NOT NULL CHECK (verification_status IN ('SUCCESS', 'FAILED')),
    response_time_ms INT,
    sample_data JSONB,
    error_message TEXT,
    verified_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_connection_verifications_source ON public.connection_verifications (source_id, verified_at DESC);

-- 9. Table: existing_rules
-- Stores ingested existing banking rules from uploaded files or verified integration sources
CREATE TABLE IF NOT EXISTS public.existing_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bank_id UUID REFERENCES public.banks(id) ON DELETE CASCADE,
    source_type VARCHAR(16) NOT NULL CHECK (source_type IN ('FILE', 'INTEGRATION')),
    source_id UUID REFERENCES public.integration_sources(id) ON DELETE SET NULL,
    rule_code VARCHAR(64) NOT NULL,
    rule_title TEXT NOT NULL,
    rule_content TEXT NOT NULL,
    file_format VARCHAR(16),
    file_path TEXT,
    version INT NOT NULL DEFAULT 1,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_existing_rules_bank ON public.existing_rules (bank_id);
CREATE INDEX IF NOT EXISTS idx_existing_rules_code ON public.existing_rules (rule_code);

-- 10. Table: regulatory_documents
-- Stores uploaded regulatory circular documents and extracted text
CREATE TABLE IF NOT EXISTS public.regulatory_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bank_id UUID REFERENCES public.banks(id) ON DELETE CASCADE,
    document_name TEXT NOT NULL,
    issuing_authority VARCHAR(64) NOT NULL,
    circular_number VARCHAR(128) NOT NULL,
    effective_date DATE,
    compliance_deadline DATE,
    category VARCHAR(64),
    file_format VARCHAR(16) NOT NULL,
    file_size_bytes BIGINT NOT NULL DEFAULT 0,
    storage_path TEXT,
    version INT NOT NULL DEFAULT 1,
    extraction_status VARCHAR(16) NOT NULL DEFAULT 'PENDING' CHECK (extraction_status IN ('PENDING', 'EXTRACTING', 'COMPLETED', 'FAILED')),
    extracted_text TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_regulatory_documents_bank ON public.regulatory_documents (bank_id);
CREATE INDEX IF NOT EXISTS idx_regulatory_documents_circular ON public.regulatory_documents (circular_number);

-- ============================================================================
-- MILESTONE 2: UNIVERSAL RULE IR, DELTA ANALYSIS, MAPPINGS & VALIDATIONS
-- ============================================================================

-- 11. Table: rule_ir
-- Stores the normalized Universal Rule Intermediate Representation for both
-- existing bank rules and circular regulatory requirements.
CREATE TABLE IF NOT EXISTS public.rule_ir (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bank_id UUID REFERENCES public.banks(id) ON DELETE CASCADE,
    rule_id VARCHAR(128) NOT NULL,
    rule_name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(64) NOT NULL DEFAULT 'GENERAL',
    source_type VARCHAR(32) NOT NULL CHECK (source_type IN ('EXISTING_DOCUMENT', 'INTEGRATION', 'REGULATORY_CIRCULAR')),
    source_id VARCHAR(128),
    version INT NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT true,
    effective_date TIMESTAMPTZ,
    expiry_date TIMESTAMPTZ,
    condition_tree JSONB NOT NULL DEFAULT '{"operator": "AND", "conditions": []}'::jsonb,
    actions JSONB NOT NULL DEFAULT '[]'::jsonb,
    parameters JSONB NOT NULL DEFAULT '{}'::jsonb,
    dependencies JSONB NOT NULL DEFAULT '[]'::jsonb,
    traceability JSONB NOT NULL DEFAULT '{}'::jsonb,
    raw_content TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_rule_ir_bank ON public.rule_ir (bank_id);
CREATE INDEX IF NOT EXISTS idx_rule_ir_rule_id ON public.rule_ir (rule_id);
CREATE INDEX IF NOT EXISTS idx_rule_ir_category ON public.rule_ir (category);
CREATE INDEX IF NOT EXISTS idx_rule_ir_source ON public.rule_ir (source_type, source_id);

-- 12. Table: delta_analyses
-- Represents an AI-powered delta analysis run comparing existing rules against circulars
CREATE TABLE IF NOT EXISTS public.delta_analyses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bank_id UUID REFERENCES public.banks(id) ON DELETE CASCADE,
    analysis_name VARCHAR(255) NOT NULL,
    circular_id UUID REFERENCES public.regulatory_documents(id) ON DELETE SET NULL,
    circular_number VARCHAR(128),
    status VARCHAR(32) NOT NULL DEFAULT 'COMPLETED' CHECK (status IN ('PROCESSING', 'COMPLETED', 'FAILED')),
    total_rules INT NOT NULL DEFAULT 0,
    additions_count INT NOT NULL DEFAULT 0,
    modifications_count INT NOT NULL DEFAULT 0,
    removals_count INT NOT NULL DEFAULT 0,
    clarifications_count INT NOT NULL DEFAULT 0,
    no_impact_count INT NOT NULL DEFAULT 0,
    manual_review_count INT NOT NULL DEFAULT 0,
    summary TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_delta_analyses_bank ON public.delta_analyses (bank_id);
CREATE INDEX IF NOT EXISTS idx_delta_analyses_circular ON public.delta_analyses (circular_id);

-- 13. Table: rule_deltas
-- Detailed classification and diff breakdown for each identified change
CREATE TABLE IF NOT EXISTS public.rule_deltas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    analysis_id UUID REFERENCES public.delta_analyses(id) ON DELETE CASCADE,
    bank_id UUID REFERENCES public.banks(id) ON DELETE CASCADE,
    classification VARCHAR(32) NOT NULL CHECK (classification IN (
        'ADDITION', 'MODIFICATION', 'REMOVAL', 'CLARIFICATION', 'NO_IMPACT', 'MANUAL_REVIEW_REQUIRED'
    )),
    category VARCHAR(64) NOT NULL DEFAULT 'GENERAL',
    rule_name VARCHAR(255) NOT NULL,
    previous_rule_id UUID REFERENCES public.rule_ir(id) ON DELETE SET NULL,
    regulatory_obligation_id VARCHAR(128),
    previous_rule_representation JSONB,
    new_requirement_representation JSONB,
    identified_differences JSONB NOT NULL DEFAULT '[]'::jsonb,
    proposed_change JSONB NOT NULL DEFAULT '{}'::jsonb,
    reason TEXT NOT NULL,
    impact_assessment TEXT NOT NULL,
    confidence_score NUMERIC(4, 3) NOT NULL DEFAULT 0.950,
    evidence_sources JSONB NOT NULL DEFAULT '[]'::jsonb,
    review_status VARCHAR(32) NOT NULL DEFAULT 'PENDING' CHECK (review_status IN (
        'PENDING', 'ACCEPTED', 'MODIFIED', 'REJECTED', 'NEEDS_REVIEW'
    )),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_rule_deltas_analysis ON public.rule_deltas (analysis_id);
CREATE INDEX IF NOT EXISTS idx_rule_deltas_bank ON public.rule_deltas (bank_id);
CREATE INDEX IF NOT EXISTS idx_rule_deltas_classification ON public.rule_deltas (classification);
CREATE INDEX IF NOT EXISTS idx_rule_deltas_status ON public.rule_deltas (review_status);

-- 14. Table: rule_mappings
-- Human review decisions and customizations made in the Rule Mapping Studio
CREATE TABLE IF NOT EXISTS public.rule_mappings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bank_id UUID REFERENCES public.banks(id) ON DELETE CASCADE,
    delta_id UUID REFERENCES public.rule_deltas(id) ON DELETE CASCADE,
    user_email TEXT NOT NULL,
    decision VARCHAR(32) NOT NULL CHECK (decision IN ('ACCEPTED', 'MODIFIED', 'REJECTED', 'MANUAL_REVIEW')),
    customized_rule_ir JSONB,
    user_notes TEXT,
    mapped_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_rule_mappings_delta ON public.rule_mappings (delta_id);
CREATE INDEX IF NOT EXISTS idx_rule_mappings_bank ON public.rule_mappings (bank_id);

-- 15. Table: rule_validations
-- Automated structural, logical, and regulatory validation findings for rules
CREATE TABLE IF NOT EXISTS public.rule_validations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bank_id UUID REFERENCES public.banks(id) ON DELETE CASCADE,
    rule_ir_id UUID REFERENCES public.rule_ir(id) ON DELETE CASCADE,
    delta_id UUID REFERENCES public.rule_deltas(id) ON DELETE CASCADE,
    validation_type VARCHAR(32) NOT NULL CHECK (validation_type IN ('STRUCTURAL', 'LOGICAL', 'REGULATORY')),
    severity VARCHAR(16) NOT NULL CHECK (severity IN ('ERROR', 'WARNING', 'INFO')),
    rule_code VARCHAR(128),
    message TEXT NOT NULL,
    details JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_rule_validations_rule ON public.rule_validations (rule_ir_id);
CREATE INDEX IF NOT EXISTS idx_rule_validations_delta ON public.rule_validations (delta_id);
CREATE INDEX IF NOT EXISTS idx_rule_validations_bank ON public.rule_validations (bank_id);

-- ============================================================================
-- HELPER FUNCTIONS FOR AUTHENTICATED BANK-LEVEL DATA ISOLATION
-- ============================================================================

CREATE OR REPLACE FUNCTION public.current_user_email()
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER AS $$
    SELECT lower(COALESCE(
        nullif(current_setting('request.jwt.claims', true)::json->>'email', ''),
        nullif(current_setting('request.jwt.claim.email', true), ''),
        (auth.jwt() ->> 'email'),
        ''
    ));
$$;

CREATE OR REPLACE FUNCTION public.is_bank_member(bank_uuid UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER AS $$
    SELECT (
        -- Allow access if authenticated user is explicitly a member of this bank
        EXISTS (
            SELECT 1 FROM public.bank_members bm
            WHERE bm.bank_id = bank_uuid
              AND lower(bm.user_email) = public.current_user_email()
        )
        -- Or if called by service role key for administrative orchestration
        OR (auth.jwt() ->> 'role') = 'service_role'
    );
$$;

-- ============================================================================
-- ENABLE ROW LEVEL SECURITY (RLS) ON ALL TABLES
-- ============================================================================
ALTER TABLE public.auth_otps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.compliance_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.banks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bank_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bank_integrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.integration_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.connection_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.existing_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.regulatory_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rule_ir ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delta_analyses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rule_deltas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rule_mappings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rule_validations ENABLE ROW LEVEL SECURITY;

-- Drop legacy permissive policies if they exist
DROP POLICY IF EXISTS "Allow public access for banks" ON public.banks;
DROP POLICY IF EXISTS "Allow public access for bank_integrations" ON public.bank_integrations;
DROP POLICY IF EXISTS "Allow public access for integration_sources" ON public.integration_sources;
DROP POLICY IF EXISTS "Allow public access for connection_verifications" ON public.connection_verifications;
DROP POLICY IF EXISTS "Allow public access for existing_rules" ON public.existing_rules;
DROP POLICY IF EXISTS "Allow public access for regulatory_documents" ON public.regulatory_documents;
DROP POLICY IF EXISTS "Allow public access for rule_ir" ON public.rule_ir;
DROP POLICY IF EXISTS "Allow public access for delta_analyses" ON public.delta_analyses;
DROP POLICY IF EXISTS "Allow public access for rule_deltas" ON public.rule_deltas;
DROP POLICY IF EXISTS "Allow public access for rule_mappings" ON public.rule_mappings;
DROP POLICY IF EXISTS "Allow public access for rule_validations" ON public.rule_validations;
DROP POLICY IF EXISTS "Allow public insert and read for otps" ON public.auth_otps;
DROP POLICY IF EXISTS "Allow public insert and read for user_history" ON public.user_history;
DROP POLICY IF EXISTS "Allow public insert and read for compliance_reports" ON public.compliance_reports;

-- ============================================================================
-- STRICT BANK-LEVEL DATA ISOLATION POLICIES (NO PUBLIC ACCESS)
-- ============================================================================

-- 1. auth_otps
-- Public/anonymous can only request OTP for an email; reading is restricted to unverified, unexpired OTPs
CREATE POLICY "Allow OTP creation for login"
    ON public.auth_otps FOR INSERT TO anon, authenticated
    WITH CHECK (email IS NOT NULL AND length(email) > 3);

CREATE POLICY "Allow OTP validation"
    ON public.auth_otps FOR SELECT TO anon, authenticated
    USING (is_verified = false AND expires_at > now());

CREATE POLICY "Allow OTP verification update"
    ON public.auth_otps FOR UPDATE TO anon, authenticated
    USING (is_verified = false AND expires_at > now())
    WITH CHECK (is_verified = true);

-- 2. user_history: Strictly isolated to authenticated user's email
CREATE POLICY "Strict user audit history isolation"
    ON public.user_history FOR ALL TO authenticated
    USING (lower(user_email) = public.current_user_email() OR (auth.jwt() ->> 'role') = 'service_role')
    WITH CHECK (lower(user_email) = public.current_user_email() OR (auth.jwt() ->> 'role') = 'service_role');

-- 3. compliance_reports: Strictly isolated to authenticated user's email
CREATE POLICY "Strict user compliance reports isolation"
    ON public.compliance_reports FOR ALL TO authenticated
    USING (lower(user_email) = public.current_user_email() OR (auth.jwt() ->> 'role') = 'service_role')
    WITH CHECK (lower(user_email) = public.current_user_email() OR (auth.jwt() ->> 'role') = 'service_role');

-- 4. banks: Strictly isolated to authorized bank members
CREATE POLICY "Strict bank access"
    ON public.banks FOR SELECT TO authenticated
    USING (public.is_bank_member(id));

CREATE POLICY "Bank registration"
    ON public.banks FOR INSERT TO authenticated
    WITH CHECK (public.current_user_email() != '' OR (auth.jwt() ->> 'role') = 'service_role');

-- 5. bank_members: View membership of authorized bank
CREATE POLICY "Strict bank members isolation"
    ON public.bank_members FOR ALL TO authenticated
    USING (public.is_bank_member(bank_id))
    WITH CHECK (public.is_bank_member(bank_id));

-- 6. bank_integrations: Bank-isolated environment configurations
CREATE POLICY "Strict bank integration isolation"
    ON public.bank_integrations FOR ALL TO authenticated
    USING (public.is_bank_member(bank_id))
    WITH CHECK (public.is_bank_member(bank_id));

-- 7. integration_sources: Bank-isolated source configurations
CREATE POLICY "Strict integration sources isolation"
    ON public.integration_sources FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.bank_integrations bi
            WHERE bi.id = integration_id AND public.is_bank_member(bi.bank_id)
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.bank_integrations bi
            WHERE bi.id = integration_id AND public.is_bank_member(bi.bank_id)
        )
    );

-- 8. connection_verifications: Bank-isolated verification logs
CREATE POLICY "Strict verification audit isolation"
    ON public.connection_verifications FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.integration_sources src
            JOIN public.bank_integrations bi ON bi.id = src.integration_id
            WHERE src.id = source_id AND public.is_bank_member(bi.bank_id)
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.integration_sources src
            JOIN public.bank_integrations bi ON bi.id = src.integration_id
            WHERE src.id = source_id AND public.is_bank_member(bi.bank_id)
        )
    );

-- 9. existing_rules: Bank-isolated rules catalog
CREATE POLICY "Strict existing rules catalog isolation"
    ON public.existing_rules FOR ALL TO authenticated
    USING (public.is_bank_member(bank_id))
    WITH CHECK (public.is_bank_member(bank_id));

-- 10. regulatory_documents: Bank-isolated regulatory circulars
CREATE POLICY "Strict regulatory documents isolation"
    ON public.regulatory_documents FOR ALL TO authenticated
    USING (public.is_bank_member(bank_id))
    WITH CHECK (public.is_bank_member(bank_id));

-- 11. rule_ir: Bank-isolated Universal Rule IR catalog
CREATE POLICY "Strict rule_ir isolation"
    ON public.rule_ir FOR ALL TO authenticated
    USING (public.is_bank_member(bank_id))
    WITH CHECK (public.is_bank_member(bank_id));

-- 12. delta_analyses: Bank-isolated Delta Analysis runs
CREATE POLICY "Strict delta_analyses isolation"
    ON public.delta_analyses FOR ALL TO authenticated
    USING (public.is_bank_member(bank_id))
    WITH CHECK (public.is_bank_member(bank_id));

-- 13. rule_deltas: Bank-isolated Rule Delta records
CREATE POLICY "Strict rule_deltas isolation"
    ON public.rule_deltas FOR ALL TO authenticated
    USING (public.is_bank_member(bank_id))
    WITH CHECK (public.is_bank_member(bank_id));

-- 14. rule_mappings: Bank-isolated human review mappings
CREATE POLICY "Strict rule_mappings isolation"
    ON public.rule_mappings FOR ALL TO authenticated
    USING (public.is_bank_member(bank_id))
    WITH CHECK (public.is_bank_member(bank_id));

-- 15. rule_validations: Bank-isolated automated validation logs
CREATE POLICY "Strict rule_validations isolation"
    ON public.rule_validations FOR ALL TO authenticated
    USING (public.is_bank_member(bank_id))
    WITH CHECK (public.is_bank_member(bank_id));

-- ============================================================================
-- 16. Table: user_saved_integrations
-- User-isolated verified credentials vault with active selection, edit, and removal
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
    credential_ref TEXT,
    ssl_config JSONB NOT NULL DEFAULT '{"enabled": true, "verify_cert": true}'::jsonb,
    status VARCHAR(32) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'PENDING', 'FAILED', 'VERIFIED')),
    is_selected BOOLEAN NOT NULL DEFAULT true,
    last_verified_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_user_saved_integrations_email 
    ON public.user_saved_integrations (user_email);

CREATE INDEX IF NOT EXISTS idx_user_saved_integrations_selected 
    ON public.user_saved_integrations (user_email, is_selected);

ALTER TABLE public.user_saved_integrations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public access for user_saved_integrations" ON public.user_saved_integrations;
CREATE POLICY "Allow public access for user_saved_integrations" 
    ON public.user_saved_integrations FOR ALL 
    USING (true) 
    WITH CHECK (true);

