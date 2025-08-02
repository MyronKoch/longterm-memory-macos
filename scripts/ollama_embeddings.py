#!/usr/bin/env python3
"""
Ollama Embeddings for Claude Memory System
Uses nomic-embed-text model for local embeddings
WITH AUTOMATIC CHUNKING for long observations
"""

import json
import subprocess
import psycopg2
from psycopg2.extras import RealDictCursor
import numpy as np
from typing import List, Dict, Optional, Tuple
import sys
import time
import re

# Database configuration (use environment variables or defaults)
import os

DB_CONFIG = {
    'host': os.getenv('LONGTERM_MEMORY_HOST', 'localhost'),
    'port': int(os.getenv('LONGTERM_MEMORY_PORT', '5432')),
    'database': os.getenv('LONGTERM_MEMORY_DB', 'longterm_memory'),
    'user': os.getenv('LONGTERM_MEMORY_USER', os.getenv('USER', 'postgres')),
    'password': os.getenv('LONGTERM_MEMORY_PASSWORD', '')
}

# Chunking configuration
MAX_CHUNK_SIZE = 800  # Characters per chunk
CHUNK_OVERLAP = 50    # Overlap between chunks for context

def get_ollama_embedding(text: str, model: str = "nomic-embed-text:f32") -> Optional[List[float]]:
    """Get embedding vector from Ollama, with LM Studio fallback"""
    # Clean text - remove newlines and excessive spaces
    text = ' '.join(text.split())
    
    # Try Ollama first
    try:
        payload = json.dumps({
            "model": model,
            "prompt": text
        })
        
        result = subprocess.run(
            ['curl', '-s', 'http://localhost:11434/api/embeddings',
             '-d', payload],
            capture_output=True,
            text=True,
            check=True,
            timeout=15
        )
        
        embedding_data = json.loads(result.stdout)
        
        if 'error' not in embedding_data and embedding_data.get('embedding'):
            return embedding_data['embedding']
            
    except Exception as e:
        pass  # Fall through to LM Studio
    
    # Try LM Studio as fallback (OpenAI-compatible API)
    try:
        payload = json.dumps({
            "model": "nomic-embed-text-v1.5",
            "input": text
        })
        
        result = subprocess.run(
            ['curl', '-s', 'http://localhost:1234/v1/embeddings',
             '-H', 'Content-Type: application/json',
             '-d', payload],
            capture_output=True,
            text=True,
            check=True,
            timeout=15
        )
        
        embedding_data = json.loads(result.stdout)
        
        # OpenAI format: {"data": [{"embedding": [...]}]}
        if 'data' in embedding_data and embedding_data['data']:
            embedding = embedding_data['data'][0].get('embedding', [])
            if embedding:
                return embedding
                
    except Exception as e:
        print(f"  ⚠️  Both Ollama and LM Studio failed: {e}")
        return None
    
    return None

def smart_chunk_text(text: str, max_size: int = MAX_CHUNK_SIZE) -> List[str]:
    """
    Intelligently chunk text by:
    1. Splitting on numbered topics like (1), (2), etc.
    2. Falling back to sentence boundaries if no topics
    3. Hard splitting if sentences are too long
    """
    # Try to split by numbered topics first
    topic_pattern = r'\(\d+\)\s+[^-]+'
    topics = re.split(r'(?=\(\d+\))', text)
    
    if len(topics) > 1 and all(len(t) < max_size for t in topics if t.strip()):
        # Clean split by topics - each topic is under max_size
        return [t.strip() for t in topics if t.strip()]
    
    # Fall back to sentence-based chunking
    sentences = re.split(r'(?<=[.!?])\s+', text)
    chunks = []
    current_chunk = ""
    
    for sentence in sentences:
        if len(current_chunk) + len(sentence) < max_size:
            current_chunk += sentence + " "
        else:
            if current_chunk:
                chunks.append(current_chunk.strip())
            current_chunk = sentence + " "
    
    if current_chunk:
        chunks.append(current_chunk.strip())
    
    return chunks if chunks else [text[:max_size]]

def chunk_long_observation(conn, obs_id: int, obs_text: str, entity_id: int, max_index: int) -> List[int]:
    """
    Chunk a long observation into multiple smaller observations
    Returns list of new observation IDs
    """
    chunks = smart_chunk_text(obs_text)
    
    if len(chunks) <= 1:
        # Not really needed, but keep original
        return []
    
    print(f"  📦 Chunking observation {obs_id} into {len(chunks)} parts...")
    
    new_obs_ids = []
    
    with conn.cursor() as cur:
        # Get the observation's date prefix
        date_match = re.match(r'^([^:]+:)', obs_text)
        date_prefix = date_match.group(1) if date_match else ""
        
        for i, chunk_text in enumerate(chunks, 1):
            # Add part indicator to chunk
            if date_prefix:
                chunk_with_part = f"{date_prefix} (Part {i}/{len(chunks)}) {chunk_text[len(date_prefix):].strip()}"
            else:
                chunk_with_part = f"(Part {i}/{len(chunks)}) {chunk_text}"
            
            # Insert new chunked observation
            cur.execute("""
                INSERT INTO observations (entity_id, observation_text, observation_index, source_type)
                VALUES (%s, %s, %s, 'chunked')
                RETURNING id
            """, (entity_id, chunk_with_part, max_index + i))
            
            new_id = cur.fetchone()[0]
            new_obs_ids.append(new_id)
            
            print(f"    ✅ Created chunk {i}/{len(chunks)} - ID: {new_id} ({len(chunk_with_part)} chars)")
        
        # Archive original observation
        cur.execute("""
            INSERT INTO observations_archive 
            SELECT * FROM observations WHERE id = %s
        """, (obs_id,))
        
        cur.execute("DELETE FROM observations WHERE id = %s", (obs_id,))
        
        conn.commit()
        print(f"    📦 Original observation {obs_id} archived")
    
    return new_obs_ids

def setup_vector_column(conn):
    """Add vector column to observations table if it doesn't exist"""
    with conn.cursor() as cur:
        # Check if embedding column exists
        cur.execute("""
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_name='observations' AND column_name='embedding'
        """)
        
        if not cur.fetchone():
            print("Adding embedding column to observations table...")
            # nomic-embed-text uses 768 dimensions
            cur.execute("""
                ALTER TABLE observations 
                ADD COLUMN embedding vector(768)
            """)
            conn.commit()
            print("✅ Added embedding column")
        else:
            print("✅ Embedding column already exists")
        
        # Create index for similarity search
        cur.execute("""
            CREATE INDEX IF NOT EXISTS observations_embedding_idx 
            ON observations USING ivfflat (embedding vector_cosine_ops) 
            WITH (lists = 100)
        """)
        conn.commit()
        print("✅ Vector index ready")

def embed_observations(conn, limit: Optional[int] = None, batch_size: int = 10):
    """Generate embeddings for observations without embeddings"""
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        # Get observations without embeddings
        query = """
            SELECT id, entity_id, observation_text 
            FROM observations 
            WHERE embedding IS NULL 
            AND observation_text IS NOT NULL
            ORDER BY created_at DESC
        """
        if limit:
            query += f" LIMIT {limit}"
        
        cur.execute(query)
        observations = cur.fetchall()
        
        if not observations:
            print("✅ All observations already have embeddings!")
            return
        
        print(f"📊 Found {len(observations)} observations to embed")
        
        embedded_count = 0
        chunked_count = 0
        
        for i, obs in enumerate(observations):
            # Progress indicator
            if i % 10 == 0:
                print(f"Processing {i+1}/{len(observations)}...")
            
            obs_text = obs['observation_text']
            
            # Check if observation is too long
            if len(obs_text) > MAX_CHUNK_SIZE:
                print(f"  ⚠️  Observation {obs['id']} is {len(obs_text)} chars (>{MAX_CHUNK_SIZE})")
                
                # Get max observation_index for this entity
                cur.execute("""
                    SELECT MAX(observation_index) as max_index
                    FROM observations
                    WHERE entity_id = %s
                """, (obs['entity_id'],))
                result = cur.fetchone()
                max_index = result['max_index'] if result and result['max_index'] is not None else 0
                
                # Chunk it
                new_ids = chunk_long_observation(conn, obs['id'], obs_text, obs['entity_id'], max_index)
                
                if new_ids:
                    chunked_count += 1
                    # Embed the new chunks
                    for new_id in new_ids:
                        cur.execute("SELECT observation_text FROM observations WHERE id = %s", (new_id,))
                        chunk_result = cur.fetchone()
                        chunk_text = chunk_result['observation_text'] if chunk_result else None

                        if not chunk_text:
                            continue
                        
                        embedding = get_ollama_embedding(chunk_text)
                        
                        if embedding:
                            cur.execute("""
                                UPDATE observations 
                                SET embedding = %s::vector 
                                WHERE id = %s
                            """, (embedding, new_id))
                            embedded_count += 1
                        
                        time.sleep(0.1)
                    
                    conn.commit()
                    continue
            
            # Normal embedding for observations under MAX_CHUNK_SIZE
            embedding = get_ollama_embedding(obs_text)
            
            if embedding:
                # Store in database
                cur.execute("""
                    UPDATE observations 
                    SET embedding = %s::vector 
                    WHERE id = %s
                """, (embedding, obs['id']))
                embedded_count += 1
                
                # Commit in batches
                if embedded_count % batch_size == 0:
                    conn.commit()
                    print(f"  Committed {embedded_count} embeddings")
            else:
                print(f"  ⚠️  Failed to embed observation {obs['id']}")
            
            # Small delay to avoid overloading
            time.sleep(0.1)
        
        # Final commit
        conn.commit()
        print(f"\n✅ Results:")
        print(f"   Generated {embedded_count} embeddings")
        print(f"   Chunked {chunked_count} long observations")

def semantic_search(conn, query: str, limit: int = 10) -> List[Dict]:
    """Search observations using semantic similarity"""
    # Get embedding for query
    query_embedding = get_ollama_embedding(query)
    
    if not query_embedding:
        print("Failed to generate query embedding")
        return []
    
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        # Cosine similarity search
        cur.execute("""
            SELECT 
                o.id,
                o.observation_text,
                o.created_at,
                e.name as entity_name,
                e.entity_type,
                1 - (o.embedding <=> %s::vector) as similarity
            FROM observations o
            JOIN entities e ON o.entity_id = e.id
            WHERE o.embedding IS NOT NULL
            ORDER BY o.embedding <=> %s::vector
            LIMIT %s
        """, (query_embedding, query_embedding, limit))
        
        return cur.fetchall()

def main():
    """Main function"""
    print("🚀 Ollama Embeddings for Claude Memory System v2.0")
    print(f"   Using model: nomic-embed-text (768 dimensions)")
    print(f"   Auto-chunking: Observations >{MAX_CHUNK_SIZE} chars")
    
    # Connect to database
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        print("✅ Connected to PostgreSQL")
        
        # Setup vector column
        setup_vector_column(conn)
        
        # Check command line arguments
        if len(sys.argv) > 1:
            command = sys.argv[1]
            
            if command == "embed":
                # Embed all observations without embeddings
                limit = int(sys.argv[2]) if len(sys.argv) > 2 else None
                embed_observations(conn, limit)
                
            elif command == "search":
                # Semantic search
                if len(sys.argv) < 3:
                    print("Usage: python ollama_embeddings.py search 'your query here'")
                    return
                
                query = ' '.join(sys.argv[2:])
                print(f"\n🔍 Searching for: {query}")
                
                results = semantic_search(conn, query)
                
                print(f"\n📊 Found {len(results)} results:\n")
                for r in results:
                    print(f"[{r['similarity']:.3f}] {r['entity_name']} ({r['entity_type']}) - {r['created_at']}")
                    print(f"  {r['observation_text'][:200]}...")
                    print()
            else:
                print(f"Unknown command: {command}")
                print("Available commands: embed, search")
        else:
            print("\nUsage:")
            print("  Embed observations: python ollama_embeddings.py embed [limit]")
            print("  Search: python ollama_embeddings.py search 'your query'")
            
            # Show stats
            with conn.cursor() as cur:
                cur.execute("SELECT COUNT(*) as total FROM observations")
                total = cur.fetchone()[0]
                
                cur.execute("SELECT COUNT(*) as embedded FROM observations WHERE embedding IS NOT NULL")
                embedded = cur.fetchone()[0]
                
                cur.execute("SELECT COUNT(*) FROM observations WHERE source_type = 'chunked'")
                chunked = cur.fetchone()[0]
                
                print(f"\n📊 Current Status:")
                print(f"   Total observations: {total}")
                print(f"   With embeddings: {embedded}")
                print(f"   Chunked observations: {chunked}")
                print(f"   Remaining: {total - embedded}")
        
    except psycopg2.Error as e:
        print(f"❌ Database error: {e}")
    finally:
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    main()
