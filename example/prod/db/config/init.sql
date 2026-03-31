-- init.sql
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS documents (
    id BIGSERIAL PRIMARY KEY,
    repo TEXT NOT NULL,
    path TEXT NOT NULL,
    chunk_id INT NOT NULL,
    content TEXT NOT NULL,
    embedding VECTOR(1024),
    metadata JSONB
);

CREATE INDEX IF NOT EXISTS documents_embedding_idx
  ON documents USING hnsw (embedding vector_cosine_ops);

CREATE INDEX IF NOT EXISTS idx_documents_metadata
  ON documents USING gin (metadata);
