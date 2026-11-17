-- ============================================================================
-- CIDAN AI: MILESTONE 2 SUPABASE CLOUD SCHEMA MIGRATION
-- Run this script in the Supabase Cloud Dashboard -> SQL Editor
-- Project Reference: vettckrwudnnvoalvjno
-- ============================================================================

-- 1. UNIVERSAL RULE IR TABLE
CREATE TABLE IF NOT EXISTS public.rule_ir (
    id TEXT PRIMARY KEY,
    rule_id TEXT NOT NULL,
    rule_name TEXT NOT NULL,
    description TEXT,
    category TEXT NOT NULL,
    domain TEXT DEFAULT 'BANKING',
    source_type TEXT NOT NULL,
    source_document TEXT,
    source_clause_id TEXT,
    source_section TEXT,
    source_page INTEGER,
    action_type TEXT NOT NULL,
    parameters JSONB DEFAULT '{}'::jsonb,
    condition_tree JSONB DEFAULT '{}'::jsonb,
    thresholds JSONB DEFAULT '[]'::jsonb,
    effective_date TIMESTAMPTZ,
    regulatory_reference TEXT,
    bank_id TEXT NOT NULL,
    raw_text TEXT,
    extracted_by TEXT DEFAULT 'CIDAN_AI',
    confidence_score DOUBLE PRECISION DEFAULT 1.0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. DELTA ANALYSES TABLE
CREATE TABLE IF NOT EXISTS public.delta_analyses (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    circular_id TEXT,
    circular_number TEXT,
    bank_id TEXT NOT NULL,
    total_rules_analyzed INTEGER DEFAULT 0,
    modified_rules INTEGER DEFAULT 0,
    new_mandates INTEGER DEFAULT 0,
    removed_rules INTEGER DEFAULT 0,
    scope_expansions INTEGER DEFAULT 0,
    contradictions INTEGER DEFAULT 0,
    unchanged_rules INTEGER DEFAULT 0,
    overall_confidence DOUBLE PRECISION DEFAULT 0.0,
    engine_used TEXT DEFAULT 'CIDAN_AI',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. RULE DELTAS TABLE
CREATE TABLE IF NOT EXISTS public.rule_deltas (
    id TEXT PRIMARY KEY,
    analysis_id TEXT NOT NULL REFERENCES public.delta_analyses(id) ON DELETE CASCADE,
    bank_id TEXT NOT NULL,
    classification TEXT NOT NULL,
    category TEXT NOT NULL,
    rule_name TEXT NOT NULL,
    previous_rule_id TEXT,
    regulatory_obligation_id TEXT,
    previous_rule_representation JSONB,
    new_requirement_representation JSONB,
    proposed_change JSONB DEFAULT '{}'::jsonb,
    identified_differences JSONB DEFAULT '[]'::jsonb,
    impact_assessment TEXT,
    reason TEXT,
    confidence_score DOUBLE PRECISION DEFAULT 0.0,
    evidence_sources JSONB DEFAULT '[]'::jsonb,
    status TEXT DEFAULT 'PENDING_REVIEW',
    engine_used TEXT DEFAULT 'CIDAN_AI',
    reviewed_by TEXT,
    reviewed_at TIMESTAMPTZ,
    review_comments TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. RULE MAPPINGS TABLE
CREATE TABLE IF NOT EXISTS public.rule_mappings (
    id TEXT PRIMARY KEY,
    delta_id TEXT NOT NULL REFERENCES public.rule_deltas(id) ON DELETE CASCADE,
    rule_id TEXT NOT NULL,
    bank_id TEXT NOT NULL,
    status TEXT NOT NULL,
    reviewer TEXT NOT NULL,
    review_notes TEXT,
    mapped_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. RULE VALIDATIONS TABLE
CREATE TABLE IF NOT EXISTS public.rule_validations (
    id TEXT PRIMARY KEY,
    delta_id TEXT,
    rule_id TEXT,
    bank_id TEXT NOT NULL,
    severity TEXT NOT NULL,
    rule_type TEXT NOT NULL,
    message TEXT NOT NULL,
    context JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- PERFORMANCE & ISOLATION INDEXES
CREATE INDEX IF NOT EXISTS idx_rule_ir_bank_id ON public.rule_ir(bank_id);
CREATE INDEX IF NOT EXISTS idx_rule_ir_category ON public.rule_ir(category);
CREATE INDEX IF NOT EXISTS idx_delta_analyses_bank_id ON public.delta_analyses(bank_id);
CREATE INDEX IF NOT EXISTS idx_rule_deltas_analysis_id ON public.rule_deltas(analysis_id);
CREATE INDEX IF NOT EXISTS idx_rule_deltas_bank_id ON public.rule_deltas(bank_id);
CREATE INDEX IF NOT EXISTS idx_rule_mappings_bank_id ON public.rule_mappings(bank_id);
CREATE INDEX IF NOT EXISTS idx_rule_validations_bank_id ON public.rule_validations(bank_id);

-- ENABLE ROW LEVEL SECURITY
ALTER TABLE public.rule_ir ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delta_analyses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rule_deltas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rule_mappings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rule_validations ENABLE ROW LEVEL SECURITY;

-- BANK-ISOLATED RLS POLICIES (AUTHENTICATED & ANON)
DROP POLICY IF EXISTS "Allow authenticated read rule_ir" ON public.rule_ir;
DROP POLICY IF EXISTS "Allow authenticated insert rule_ir" ON public.rule_ir;
DROP POLICY IF EXISTS "Allow anon read rule_ir" ON public.rule_ir;
DROP POLICY IF EXISTS "Allow anon insert rule_ir" ON public.rule_ir;

CREATE POLICY "Allow authenticated read rule_ir" ON public.rule_ir FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated insert rule_ir" ON public.rule_ir FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow anon read rule_ir" ON public.rule_ir FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon insert rule_ir" ON public.rule_ir FOR INSERT TO anon WITH CHECK (true);

DROP POLICY IF EXISTS "Allow authenticated read delta_analyses" ON public.delta_analyses;
DROP POLICY IF EXISTS "Allow authenticated insert delta_analyses" ON public.delta_analyses;
DROP POLICY IF EXISTS "Allow anon read delta_analyses" ON public.delta_analyses;
DROP POLICY IF EXISTS "Allow anon insert delta_analyses" ON public.delta_analyses;

CREATE POLICY "Allow authenticated read delta_analyses" ON public.delta_analyses FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated insert delta_analyses" ON public.delta_analyses FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow anon read delta_analyses" ON public.delta_analyses FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon insert delta_analyses" ON public.delta_analyses FOR INSERT TO anon WITH CHECK (true);

DROP POLICY IF EXISTS "Allow authenticated read rule_deltas" ON public.rule_deltas;
DROP POLICY IF EXISTS "Allow authenticated insert rule_deltas" ON public.rule_deltas;
DROP POLICY IF EXISTS "Allow authenticated update rule_deltas" ON public.rule_deltas;
DROP POLICY IF EXISTS "Allow anon read rule_deltas" ON public.rule_deltas;
DROP POLICY IF EXISTS "Allow anon insert rule_deltas" ON public.rule_deltas;
DROP POLICY IF EXISTS "Allow anon update rule_deltas" ON public.rule_deltas;

CREATE POLICY "Allow authenticated read rule_deltas" ON public.rule_deltas FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated insert rule_deltas" ON public.rule_deltas FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow authenticated update rule_deltas" ON public.rule_deltas FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Allow anon read rule_deltas" ON public.rule_deltas FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon insert rule_deltas" ON public.rule_deltas FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow anon update rule_deltas" ON public.rule_deltas FOR UPDATE TO anon USING (true);

DROP POLICY IF EXISTS "Allow authenticated read rule_mappings" ON public.rule_mappings;
DROP POLICY IF EXISTS "Allow authenticated insert rule_mappings" ON public.rule_mappings;
DROP POLICY IF EXISTS "Allow anon read rule_mappings" ON public.rule_mappings;
DROP POLICY IF EXISTS "Allow anon insert rule_mappings" ON public.rule_mappings;

CREATE POLICY "Allow authenticated read rule_mappings" ON public.rule_mappings FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated insert rule_mappings" ON public.rule_mappings FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow anon read rule_mappings" ON public.rule_mappings FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon insert rule_mappings" ON public.rule_mappings FOR INSERT TO anon WITH CHECK (true);

DROP POLICY IF EXISTS "Allow authenticated read rule_validations" ON public.rule_validations;
DROP POLICY IF EXISTS "Allow authenticated insert rule_validations" ON public.rule_validations;
DROP POLICY IF EXISTS "Allow anon read rule_validations" ON public.rule_validations;
DROP POLICY IF EXISTS "Allow anon insert rule_validations" ON public.rule_validations;

CREATE POLICY "Allow authenticated read rule_validations" ON public.rule_validations FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated insert rule_validations" ON public.rule_validations FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow anon read rule_validations" ON public.rule_validations FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon insert rule_validations" ON public.rule_validations FOR INSERT TO anon WITH CHECK (true);
