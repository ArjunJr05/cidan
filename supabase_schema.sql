-- ============================================================================
-- CIDAN Banking Regulatory AI - Supabase Database Schema
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

-- Index for rapid OTP lookup by email & code
CREATE INDEX IF NOT EXISTS idx_auth_otps_email_code ON public.auth_otps (email, otp_code, is_verified);
CREATE INDEX IF NOT EXISTS idx_auth_otps_expires ON public.auth_otps (expires_at);

-- 2. Table: user_history
-- Records complete compliance audit trail per user email (logins, uploads, reviews, approvals)
CREATE TABLE IF NOT EXISTS public.user_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_email TEXT NOT NULL,
    action_type TEXT NOT NULL, -- 'OTP_REQUESTED', 'LOGIN_SUCCESS', 'DOCUMENT_UPLOADED', 'COMPLIANCE_AUDIT_SAVED', 'POLICY_APPROVED'
    document_name TEXT,
    document_id TEXT,
    workflow_id TEXT,
    compliance_score INT,
    summary TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Index for fast user activity history querying
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

-- Index for retrieving reports by email and workflow
CREATE INDEX IF NOT EXISTS idx_compliance_reports_email ON public.compliance_reports (user_email, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_compliance_reports_workflow ON public.compliance_reports (workflow_id);

-- Enable Row Level Security (RLS)
ALTER TABLE public.auth_otps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.compliance_reports ENABLE ROW LEVEL SECURITY;

-- Anonymous client read/write policies for mobile app integration
-- (You can restrict these further if using Supabase Auth JWT)
CREATE POLICY "Allow public insert and read for otps"
    ON public.auth_otps
    FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Allow public insert and read for user_history"
    ON public.user_history
    FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Allow public insert and read for compliance_reports"
    ON public.compliance_reports
    FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);
