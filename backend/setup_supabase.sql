-- ============================================================
-- SecureVault AI — Supabase Database Setup Script
-- Run this in the Supabase Dashboard > SQL Editor
-- ============================================================

-- 1. Create 'users' table
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(36) PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,
    full_name VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 2. Create 'documents' table
CREATE TABLE IF NOT EXISTS documents (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL REFERENCES users(id),
    original_name VARCHAR(255) NOT NULL,
    encrypted_filename VARCHAR(255) NOT NULL,
    file_size INTEGER NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    content_hash VARCHAR(64),
    category VARCHAR(50) DEFAULT 'General',
    sensitivity VARCHAR(20) DEFAULT 'LOW',
    pii_summary JSONB DEFAULT '{}',
    summary_preview TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 3. Create 'audit_logs' table
CREATE TABLE IF NOT EXISTS audit_logs (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL REFERENCES users(id),
    action VARCHAR(100) NOT NULL,
    ip_address VARCHAR(45) DEFAULT '127.0.0.1',
    risk_score INTEGER DEFAULT 0,
    is_anomaly BOOLEAN DEFAULT FALSE,
    details JSONB DEFAULT '{}',
    timestamp TIMESTAMP DEFAULT NOW()
);

-- 4. Create 'anomaly_alerts' table
CREATE TABLE IF NOT EXISTS anomaly_alerts (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL REFERENCES users(id),
    severity VARCHAR(20) DEFAULT 'WARNING',
    risk_score INTEGER NOT NULL,
    reasons JSONB DEFAULT '[]',
    is_resolved BOOLEAN DEFAULT FALSE,
    timestamp TIMESTAMP DEFAULT NOW()
);

-- 5. Create 'user_biometrics' table (persisting lock & biometric registration to cloud)
CREATE TABLE IF NOT EXISTS user_biometrics (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    fingerprint_enrolled BOOLEAN DEFAULT FALSE,
    facelock_enrolled BOOLEAN DEFAULT FALSE,
    face_template_hash TEXT,
    face_landmarks_data TEXT,
    dual_biometric_required BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 6. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_documents_user_id ON documents(user_id);
CREATE INDEX IF NOT EXISTS idx_documents_category ON documents(category);
CREATE INDEX IF NOT EXISTS idx_documents_sensitivity ON documents(sensitivity);
CREATE INDEX IF NOT EXISTS idx_documents_content_hash ON documents(content_hash);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_anomaly_alerts_user_id ON anomaly_alerts(user_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_user_biometrics_user_id ON user_biometrics(user_id);

-- ============================================================
-- 7. Row Level Security (RLS) Policies
-- Since the app uses the anon key with client-side user_id filtering,
-- we enable RLS but allow anon access for all operations.
-- ============================================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE anomaly_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_biometrics ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon_user_biometrics_all" ON user_biometrics FOR ALL TO anon USING (true) WITH CHECK (true);

-- Users table
CREATE POLICY "anon_users_select" ON users FOR SELECT TO anon USING (true);
CREATE POLICY "anon_users_insert" ON users FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "anon_users_update" ON users FOR UPDATE TO anon USING (true);

-- Documents table
CREATE POLICY "anon_documents_select" ON documents FOR SELECT TO anon USING (true);
CREATE POLICY "anon_documents_insert" ON documents FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "anon_documents_update" ON documents FOR UPDATE TO anon USING (true);
CREATE POLICY "anon_documents_delete" ON documents FOR DELETE TO anon USING (true);

-- Audit logs table
CREATE POLICY "anon_audit_logs_select" ON audit_logs FOR SELECT TO anon USING (true);
CREATE POLICY "anon_audit_logs_insert" ON audit_logs FOR INSERT TO anon WITH CHECK (true);

-- Anomaly alerts table
CREATE POLICY "anon_anomaly_alerts_select" ON anomaly_alerts FOR SELECT TO anon USING (true);
CREATE POLICY "anon_anomaly_alerts_insert" ON anomaly_alerts FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "anon_anomaly_alerts_update" ON anomaly_alerts FOR UPDATE TO anon USING (true);

-- ============================================================
-- 7. Storage Bucket Setup
-- ============================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('vault_files', 'vault_files', true)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS Policies for vault_files bucket
CREATE POLICY "anon_vault_files_select"
ON storage.objects FOR SELECT TO anon
USING (bucket_id = 'vault_files');

CREATE POLICY "anon_vault_files_insert"
ON storage.objects FOR INSERT TO anon
WITH CHECK (bucket_id = 'vault_files');

CREATE POLICY "anon_vault_files_update"
ON storage.objects FOR UPDATE TO anon
USING (bucket_id = 'vault_files');

CREATE POLICY "anon_vault_files_delete"
ON storage.objects FOR DELETE TO anon
USING (bucket_id = 'vault_files');

-- Done! All tables, indexes, RLS policies, and storage are set up.
