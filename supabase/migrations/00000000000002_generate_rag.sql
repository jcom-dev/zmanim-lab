-- ============================================
-- ZMANIM LAB - RAG INDEX MARKER
-- ============================================
-- This migration is a marker for the RAG indexing step.
-- The actual RAG indexing is done by running the Go indexer:
--   cd api && go run cmd/indexer/main.go
--
-- This file exists to:
-- 1. Document that RAG indexing should be run after migrations
-- 2. Mark the database as ready for AI features
--
-- Prerequisites:
--   - OPENAI_API_KEY environment variable must be set
--   - Database must have the embeddings table (from initial schema)
--
-- To run the indexer manually:
--   cd /home/coder/workspace/zmanim-lab/api
--   go run cmd/indexer/main.go
--
-- The indexer will:
--   1. Clear existing embeddings
--   2. Index DSL specification documentation
--   3. Index master zmanim registry from database
--   4. Index DSL examples
--   5. Clone and index KosherJava library
--   6. Clone and index hebcal-go library

-- Create a status entry to indicate migrations are complete
INSERT INTO ai_index_status (source, total_chunks, status)
VALUES ('migrations_complete', 0, 'pending')
ON CONFLICT (source) DO UPDATE SET
    status = 'pending',
    updated_at = NOW();

-- Add comment explaining the RAG setup
COMMENT ON TABLE ai_index_status IS 'Tracks indexing status for each knowledge source. After migrations, run: cd api && go run cmd/indexer/main.go';
