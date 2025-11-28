-- Story 4.7: AI Context System (RAG with pgvector)
-- Create embeddings table for semantic search

-- Ensure pgvector extension is enabled (from Story 4.0)
CREATE EXTENSION IF NOT EXISTS vector;

-- Create embeddings table
CREATE TABLE IF NOT EXISTS embeddings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source VARCHAR(255) NOT NULL,              -- 'dsl-spec', 'kosher-java', 'halacha'
    content_type VARCHAR(50) NOT NULL,         -- 'documentation', 'example', 'source'
    chunk_index INT NOT NULL,
    content TEXT NOT NULL,
    metadata JSONB DEFAULT '{}',               -- headers, tags, etc.
    embedding vector(1536) NOT NULL,           -- OpenAI text-embedding-3-small
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),

    UNIQUE(source, chunk_index)
);

-- Create IVFFlat index for approximate nearest neighbor search
-- Using cosine distance for semantic similarity
CREATE INDEX IF NOT EXISTS embeddings_vector_idx
ON embeddings USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- Create indexes for filtering
CREATE INDEX IF NOT EXISTS embeddings_source_idx ON embeddings(source);
CREATE INDEX IF NOT EXISTS embeddings_content_type_idx ON embeddings(content_type);

-- Create table for tracking index status
CREATE TABLE IF NOT EXISTS ai_index_status (
    id SERIAL PRIMARY KEY,
    source VARCHAR(255) NOT NULL UNIQUE,
    total_chunks INT NOT NULL DEFAULT 0,
    last_indexed_at TIMESTAMP,
    status VARCHAR(50) DEFAULT 'pending',      -- 'pending', 'indexing', 'complete', 'error'
    error_message TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_embeddings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updated_at
DROP TRIGGER IF EXISTS embeddings_updated_at ON embeddings;
CREATE TRIGGER embeddings_updated_at
    BEFORE UPDATE ON embeddings
    FOR EACH ROW
    EXECUTE FUNCTION update_embeddings_updated_at();

DROP TRIGGER IF EXISTS ai_index_status_updated_at ON ai_index_status;
CREATE TRIGGER ai_index_status_updated_at
    BEFORE UPDATE ON ai_index_status
    FOR EACH ROW
    EXECUTE FUNCTION update_embeddings_updated_at();

-- Comments
COMMENT ON TABLE embeddings IS 'Vector embeddings for RAG semantic search';
COMMENT ON COLUMN embeddings.source IS 'Source document identifier (dsl-spec, kosher-java, halacha)';
COMMENT ON COLUMN embeddings.content_type IS 'Type of content (documentation, example, source)';
COMMENT ON COLUMN embeddings.embedding IS 'OpenAI text-embedding-3-small 1536-dimensional vector';
COMMENT ON TABLE ai_index_status IS 'Tracks indexing status for each knowledge source';
