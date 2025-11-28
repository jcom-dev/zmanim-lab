-- Migration: AI Audit Logs for Story 4-8
-- Tracks all AI formula generation and explanation requests

CREATE TABLE IF NOT EXISTS ai_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publisher_id UUID REFERENCES publishers(id) ON DELETE SET NULL,
    user_id VARCHAR(255),  -- Clerk user ID
    request_type VARCHAR(50) NOT NULL,  -- 'generate_formula', 'explain_formula'
    input_text TEXT NOT NULL,
    output_text TEXT,
    tokens_used INT,
    model VARCHAR(100),
    confidence DECIMAL(4,3),
    success BOOLEAN NOT NULL DEFAULT false,
    error_message TEXT,
    duration_ms INT,  -- Request duration in milliseconds
    rag_context_used BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX idx_ai_audit_publisher ON ai_audit_logs(publisher_id);
CREATE INDEX idx_ai_audit_user ON ai_audit_logs(user_id);
CREATE INDEX idx_ai_audit_created ON ai_audit_logs(created_at DESC);
CREATE INDEX idx_ai_audit_type ON ai_audit_logs(request_type);
CREATE INDEX idx_ai_audit_success ON ai_audit_logs(success);

-- Comments
COMMENT ON TABLE ai_audit_logs IS 'Audit log for all AI-powered formula generation and explanation requests';
COMMENT ON COLUMN ai_audit_logs.request_type IS 'Type of AI request: generate_formula or explain_formula';
COMMENT ON COLUMN ai_audit_logs.confidence IS 'AI confidence score for generated output (0.0 to 1.0)';
COMMENT ON COLUMN ai_audit_logs.rag_context_used IS 'Whether RAG context was included in the prompt';
