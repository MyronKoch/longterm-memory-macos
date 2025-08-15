#!/usr/bin/env python3
"""
Longterm Memory Dashboard - Local Web Interface
A Flask-based dashboard for browsing, searching, and managing your semantic memory.

Run with: python3 dashboard.py
Access at: http://localhost:5555
"""

import os
import json
from datetime import datetime, timedelta
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
import psycopg2
from psycopg2.extras import RealDictCursor

app = Flask(__name__, static_folder='static')
CORS(app, origins=['http://localhost:5555', 'http://127.0.0.1:5555'])

# Configuration
DB_NAME = os.environ.get('LONGTERM_MEMORY_DB', 'longterm_memory')
DB_USER = os.environ.get('LONGTERM_MEMORY_USER', os.environ.get('USER'))
DB_HOST = os.environ.get('LONGTERM_MEMORY_HOST', 'localhost')
DB_PORT = os.environ.get('LONGTERM_MEMORY_PORT', '5432')

def get_db():
    """Get database connection."""
    return psycopg2.connect(
        dbname=DB_NAME,
        user=DB_USER,
        host=DB_HOST,
        port=DB_PORT,
        cursor_factory=RealDictCursor
    )

from contextlib import contextmanager

@contextmanager
def db_connection():
    """Context manager for database connections. Ensures cleanup on error."""
    conn = get_db()
    try:
        yield conn
    finally:
        conn.close()

@app.route('/')
def index():
    """Serve the main dashboard HTML."""
    return send_from_directory('static', 'index.html')

@app.route('/legacy')
def index_legacy():
    """Serve the legacy blue dashboard (archived)."""
    return send_from_directory('static', 'index-legacy.html')

@app.route('/graph')
def graph():
    """Serve the knowledge graph visualization."""
    return send_from_directory('static', 'graph.html')

@app.route('/api/stats')
def api_stats():
    """Get overall statistics."""
    with db_connection() as conn:
        cur = conn.cursor()
        
        # Basic counts
        cur.execute("SELECT COUNT(*) as count FROM entities")
        entity_count = cur.fetchone()['count']
        
        cur.execute("SELECT COUNT(*) as count FROM observations")
        obs_count = cur.fetchone()['count']
        
        cur.execute("SELECT COUNT(*) as count FROM observations_archive")
        archive_count = cur.fetchone()['count']
        
        cur.execute("SELECT COUNT(*) as count FROM observations WHERE embedding IS NOT NULL")
        embedded_count = cur.fetchone()['count']
        
        # Recent activity (last 7 days)
        cur.execute("""
            SELECT DATE(created_at) as date, COUNT(*) as count 
            FROM observations 
            WHERE created_at > NOW() - INTERVAL '7 days'
            GROUP BY DATE(created_at) 
            ORDER BY date DESC
        """)
        recent_activity = [dict(row) for row in cur.fetchall()]
        
        # By observation type
        cur.execute("""
            SELECT observation_type, COUNT(*) as count 
            FROM observations 
            WHERE observation_type IS NOT NULL
            GROUP BY observation_type 
            ORDER BY count DESC
        """)
        by_type = [dict(row) for row in cur.fetchall()]
        
        # By source
        cur.execute("""
            SELECT source_type, COUNT(*) as count 
            FROM observations 
            GROUP BY source_type 
            ORDER BY count DESC
        """)
        by_source = [dict(row) for row in cur.fetchall()]
        
        # High importance items
        cur.execute("""
            SELECT COUNT(*) as count FROM observations WHERE importance >= 0.8
        """)
        high_importance = cur.fetchone()['count']
        
        return jsonify({
            'entities': entity_count,
            'observations': obs_count,
            'archived': archive_count,
        'total': obs_count + archive_count,
        'embedded': embedded_count,
        'high_importance': high_importance,
        'recent_activity': recent_activity,
        'by_type': by_type,
        'by_source': by_source
    })

@app.route('/api/observations')
def api_observations():
    """Get observations with filtering and pagination."""
    # Parameters with bounds
    page = max(1, int(request.args.get('page', 1)))
    per_page = min(200, max(1, int(request.args.get('per_page', 50))))  # Clamp 1-200
    search = request.args.get('search', '').strip()
    obs_type = request.args.get('type', '')
    source = request.args.get('source', '')
    entity_id = request.args.get('entity_id', '')
    min_importance = request.args.get('min_importance', '')
    tag = request.args.get('tag', '')
    date_filter = request.args.get('date', '')  # YYYY-MM-DD format
    include_archive = request.args.get('include_archive', 'false') == 'true'
    
    offset = (page - 1) * per_page
    
    # Build query
    conditions = []
    params = []
    
    if search:
        # Search in observation text AND metadata URL
        conditions.append("(o.observation_text ILIKE %s OR o.metadata->>'url' ILIKE %s)")
        params.append(f'%{search}%')
        params.append(f'%{search}%')
    
    if obs_type:
        conditions.append("o.observation_type = %s")
        params.append(obs_type)
    
    if source:
        conditions.append("o.source_type = %s")
        params.append(source)
    
    if entity_id:
        conditions.append("o.entity_id = %s")
        params.append(int(entity_id))
    
    if min_importance:
        conditions.append("o.importance >= %s")
        params.append(float(min_importance))
    
    if tag:
        conditions.append("%s = ANY(o.tags)")
        params.append(tag)
    
    if date_filter:
        conditions.append("DATE(o.created_at) = %s")
        params.append(date_filter)
    
    where_clause = "WHERE " + " AND ".join(conditions) if conditions else ""
    
    conn = None
    try:
        conn = get_db()
        cur = conn.cursor()
    
        # Query with or without archive
        if include_archive:
            query = f"""
                SELECT o.*, e.name as entity_name, 'active' as storage
                FROM observations o
                LEFT JOIN entities e ON o.entity_id = e.id
                {where_clause}
                UNION ALL
                SELECT o.*, e.name as entity_name, 'archive' as storage
                FROM observations_archive o
                LEFT JOIN entities e ON o.entity_id = e.id
                {where_clause}
                ORDER BY created_at DESC
                LIMIT %s OFFSET %s
            """
            params = params + params  # Duplicate for UNION
        else:
            query = f"""
                SELECT o.*, e.name as entity_name, 'active' as storage
                FROM observations o
                LEFT JOIN entities e ON o.entity_id = e.id
                {where_clause}
                ORDER BY created_at DESC
                LIMIT %s OFFSET %s
            """
        
        params.extend([per_page, offset])
        cur.execute(query, params)
        observations = [dict(row) for row in cur.fetchall()]
        
        # Get total count
        if include_archive:
            count_query = f"""
                SELECT 
                    (SELECT COUNT(*) FROM observations o {where_clause}) +
                    (SELECT COUNT(*) FROM observations_archive o {where_clause}) as total
            """
            # Need params twice for the two WHERE clauses
            base_params = params[:-2]  # Remove limit/offset from duplicated params
            # base_params is already doubled from the UNION query, so it has the right count
            count_params = base_params
        else:
            count_query = f"SELECT COUNT(*) as total FROM observations o {where_clause}"
            count_params = params[:-2]
        
        cur.execute(count_query, count_params if count_params else None)
        total = cur.fetchone()['total']
    finally:
        if conn:
            conn.close()
    
    # Format dates for JSON
    for obs in observations:
        if obs.get('created_at'):
            obs['created_at'] = obs['created_at'].isoformat()
        if obs.get('metadata') and isinstance(obs['metadata'], str):
            obs['metadata'] = json.loads(obs['metadata'])
    
    return jsonify({
        'observations': observations,
        'total': total,
        'page': page,
        'per_page': per_page,
        'pages': (total + per_page - 1) // per_page
    })

@app.route('/api/archive')
def api_archive():
    """Get archived observations with pagination."""
    page = max(1, request.args.get('page', 1, type=int))
    per_page = min(200, max(1, request.args.get('per_page', 50, type=int)))  # Clamp 1-200
    search = request.args.get('search', '')
    entity_id = request.args.get('entity_id', type=int)
    
    offset = (page - 1) * per_page
    
    with db_connection() as conn:
        cur = conn.cursor()
        
        where_clauses = []
        params = []
        
        if search:
            where_clauses.append("o.observation_text ILIKE %s")
            params.append(f'%{search}%')
        
        if entity_id:
            where_clauses.append("o.entity_id = %s")
            params.append(entity_id)
        
        where_clause = "WHERE " + " AND ".join(where_clauses) if where_clauses else ""
        
        query = f"""
            SELECT o.*, e.name as entity_name
            FROM observations_archive o
            LEFT JOIN entities e ON o.entity_id = e.id
            {where_clause}
            ORDER BY created_at DESC
            LIMIT %s OFFSET %s
        """
        params.extend([per_page, offset])
        cur.execute(query, params)
        observations = [dict(row) for row in cur.fetchall()]
        
        # Get total count
        count_query = f"SELECT COUNT(*) as total FROM observations_archive o {where_clause}"
        cur.execute(count_query, params[:-2] if params[:-2] else None)
        total = cur.fetchone()['total']
    
    for obs in observations:
        if obs.get('created_at'):
            obs['created_at'] = obs['created_at'].isoformat()
    
    return jsonify({
        'observations': observations,
        'total': total,
        'page': page,
        'per_page': per_page,
        'pages': (total + per_page - 1) // per_page
    })

@app.route('/api/observation/<int:obs_id>', methods=['DELETE'])
def api_delete_observation(obs_id):
    """Delete a single observation by ID from either active or archive table."""
    with db_connection() as conn:
        cur = conn.cursor()
        
        # Check active observations first
        cur.execute("SELECT id FROM observations WHERE id = %s", (obs_id,))
        if cur.fetchone():
            cur.execute("DELETE FROM observations WHERE id = %s", (obs_id,))
            conn.commit()
            return jsonify({'success': True, 'deleted_id': obs_id, 'source': 'active'})
        
        # Check archive
        cur.execute("SELECT id FROM observations_archive WHERE id = %s", (obs_id,))
        if cur.fetchone():
            cur.execute("DELETE FROM observations_archive WHERE id = %s", (obs_id,))
            conn.commit()
            return jsonify({'success': True, 'deleted_id': obs_id, 'source': 'archive'})
        
        return jsonify({'error': 'Not found'}), 404

@app.route('/api/entities')
def api_entities():
    """Get all entities."""
    with db_connection() as conn:
        cur = conn.cursor()
        
        cur.execute("""
            SELECT e.*, 
                   (SELECT COUNT(*) FROM observations WHERE entity_id = e.id) as obs_count
            FROM entities e
            ORDER BY obs_count DESC
        """)
        entities = [dict(row) for row in cur.fetchall()]
        
        for entity in entities:
            if entity.get('created_at'):
                entity['created_at'] = entity['created_at'].isoformat()
        
        return jsonify({'entities': entities})

@app.route('/api/tags')
def api_tags():
    """Get all unique tags with counts."""
    with db_connection() as conn:
        cur = conn.cursor()
        
        cur.execute("""
            SELECT tag, COUNT(*) as count
            FROM (
                SELECT UNNEST(tags) as tag FROM observations WHERE tags IS NOT NULL
            ) t
            GROUP BY tag
            ORDER BY count DESC
        """)
        tags = [dict(row) for row in cur.fetchall()]
        
        return jsonify({'tags': tags})

@app.route('/api/graph')
def api_graph():
    """Get graph data for visualization - entities as nodes, shared tags/observations as edges."""
    with db_connection() as conn:
        cur = conn.cursor()
        
        min_observations = int(request.args.get('min_obs', 2))
        
        # Get entities with observation counts
        cur.execute("""
            SELECT e.id, e.name, e.entity_type, 
                   COUNT(o.id) as obs_count,
                   COALESCE(e.metadata->>'current_focus', '') as current_focus
            FROM entities e
            LEFT JOIN observations o ON o.entity_id = e.id
            GROUP BY e.id, e.name, e.entity_type, e.metadata
            HAVING COUNT(o.id) >= %s
            ORDER BY obs_count DESC
            LIMIT 100
        """, (min_observations,))
        
        entities = [dict(row) for row in cur.fetchall()]
        entity_ids = [e['id'] for e in entities]
        
        if not entity_ids:
            return jsonify({'nodes': [], 'links': []})
        
        # Build nodes
        nodes = []
        for e in entities:
            nodes.append({
                'id': f"entity_{e['id']}",
                'name': e['name'],
                'type': 'entity',
                'entity_type': e['entity_type'],
                'obs_count': e['obs_count'],
                'current_focus': e['current_focus'],
                'size': min(50, 10 + e['obs_count'] * 2)
            })
        
        # Get shared tags between entities (creates edges)
        cur.execute("""
            WITH entity_tags AS (
                SELECT DISTINCT o.entity_id, UNNEST(o.tags) as tag
                FROM observations o
                WHERE o.entity_id = ANY(%s) AND o.tags IS NOT NULL
            )
            SELECT et1.entity_id as source, et2.entity_id as target, 
                   COUNT(DISTINCT et1.tag) as shared_tags,
                   ARRAY_AGG(DISTINCT et1.tag) as tags
            FROM entity_tags et1
            JOIN entity_tags et2 ON et1.tag = et2.tag AND et1.entity_id < et2.entity_id
            GROUP BY et1.entity_id, et2.entity_id
            HAVING COUNT(DISTINCT et1.tag) >= 1
        """, (entity_ids,))
    
        tag_links = [dict(row) for row in cur.fetchall()]
        
        # Get entities that appear in same observations (text co-occurrence)
        cur.execute("""
            WITH entity_obs AS (
                SELECT entity_id, observation_text
                FROM observations
                WHERE entity_id = ANY(%s)
            )
            SELECT e1.id as source_id, e2.id as target_id, COUNT(*) as co_occurrences
            FROM entities e1
            CROSS JOIN entities e2
            JOIN observations o ON o.observation_text ILIKE '%%' || e1.name || '%%'
                               AND o.observation_text ILIKE '%%' || e2.name || '%%'
            WHERE e1.id < e2.id 
              AND e1.id = ANY(%s) 
              AND e2.id = ANY(%s)
              AND LENGTH(e1.name) > 3
              AND LENGTH(e2.name) > 3
            GROUP BY e1.id, e2.id
            HAVING COUNT(*) >= 1
            LIMIT 200
        """, (entity_ids, entity_ids, entity_ids))
        
        text_links = [dict(row) for row in cur.fetchall()]
        
        # Build links
        links = []
        seen_pairs = set()
        
        for link in tag_links:
            pair = (link['source'], link['target'])
            if pair not in seen_pairs:
                seen_pairs.add(pair)
                links.append({
                    'source': f"entity_{link['source']}",
                    'target': f"entity_{link['target']}",
                    'type': 'shared_tags',
                    'strength': link['shared_tags'],
                    'tags': link['tags'][:5] if link['tags'] else []
                })
        
        for link in text_links:
            pair = (link['source_id'], link['target_id'])
            if pair not in seen_pairs:
                seen_pairs.add(pair)
                links.append({
                    'source': f"entity_{link['source_id']}",
                    'target': f"entity_{link['target_id']}",
                    'type': 'co_occurrence',
                    'strength': link['co_occurrences']
                })
        
        return jsonify({
            'nodes': nodes,
            'links': links
        })

@app.route('/api/observation/<int:obs_id>')
def api_observation_detail(obs_id):
    """Get single observation detail."""
    with db_connection() as conn:
        cur = conn.cursor()
        
        cur.execute("""
            SELECT o.*, e.name as entity_name
            FROM observations o
            LEFT JOIN entities e ON o.entity_id = e.id
            WHERE o.id = %s
        """, (obs_id,))
        obs = cur.fetchone()
        
        if not obs:
            # Check archive
            cur.execute("""
                SELECT o.*, e.name as entity_name
                FROM observations_archive o
                LEFT JOIN entities e ON o.entity_id = e.id
                WHERE o.id = %s
            """, (obs_id,))
            obs = cur.fetchone()
        
        if obs:
            obs = dict(obs)
            if obs.get('created_at'):
                obs['created_at'] = obs['created_at'].isoformat()
            return jsonify(obs)
        
        return jsonify({'error': 'Not found'}), 404


@app.route('/api/search/semantic')
def api_semantic_search():
    """Semantic search using embeddings via Ollama API."""
    import urllib.request
    import urllib.error
    
    query = request.args.get('q', '').strip()
    limit = min(100, max(1, int(request.args.get('limit', 30))))  # Clamp 1-100
    min_similarity = min(1.0, max(0.0, float(request.args.get('min_similarity', 0.5))))  # Clamp 0-1
    include_archive = request.args.get('include_archive', 'false') == 'true'
    
    if not query:
        return jsonify({'error': 'Query required', 'results': [], 'count': 0, 'total_scanned': 0}), 400
    
    # Generate embedding for query - try Ollama first, then LM Studio as fallback
    embedding = None
    embedding_source = None
    errors = []
    
    # Try Ollama first (primary)
    try:
        ollama_url = 'http://localhost:11434/api/embed'
        payload = json.dumps({
            'model': 'nomic-embed-text',
            'input': query
        }).encode('utf-8')
        
        req = urllib.request.Request(
            ollama_url,
            data=payload,
            headers={'Content-Type': 'application/json'}
        )
        
        with urllib.request.urlopen(req, timeout=10) as response:
            result = json.loads(response.read().decode('utf-8'))
        
        embedding = result.get('embeddings', [[]])[0]
        if embedding:
            embedding_source = 'ollama'
            
    except Exception as e:
        errors.append(f'Ollama: {str(e)}')
    
    # Try LM Studio as fallback (OpenAI-compatible API)
    if not embedding:
        try:
            lmstudio_url = 'http://localhost:1234/v1/embeddings'
            payload = json.dumps({
                'model': 'nomic-embed-text-v1.5',  # Common embedding model in LM Studio
                'input': query
            }).encode('utf-8')
            
            req = urllib.request.Request(
                lmstudio_url,
                data=payload,
                headers={'Content-Type': 'application/json'}
            )
            
            with urllib.request.urlopen(req, timeout=10) as response:
                result = json.loads(response.read().decode('utf-8'))
            
            # OpenAI format: {"data": [{"embedding": [...]}]}
            embedding = result.get('data', [{}])[0].get('embedding', [])
            if embedding:
                embedding_source = 'lmstudio'
                
        except Exception as e:
            errors.append(f'LM Studio: {str(e)}')
    
    if not embedding:
        return jsonify({
            'error': 'No embedding service available',
            'details': errors,
            'results': []
        }), 503
    
    # Query database with vector similarity
    conn = None
    try:
        conn = get_db()
        cur = conn.cursor()
        
        embedding_str = '[' + ','.join(map(str, embedding)) + ']'
        
        if include_archive:
            # Search both tables with similarity threshold
            cur.execute("""
                WITH combined AS (
                    SELECT o.*, e.name as entity_name, 'active' as storage,
                           1 - (o.embedding <=> %s::vector) as similarity
                    FROM observations o
                    LEFT JOIN entities e ON o.entity_id = e.id
                    WHERE o.embedding IS NOT NULL
                    UNION ALL
                    SELECT o.*, e.name as entity_name, 'archive' as storage,
                           1 - (o.embedding <=> %s::vector) as similarity
                    FROM observations_archive o
                    LEFT JOIN entities e ON o.entity_id = e.id
                    WHERE o.embedding IS NOT NULL
                )
                SELECT * FROM combined
                WHERE similarity >= %s
                ORDER BY similarity DESC
                LIMIT %s
            """, (embedding_str, embedding_str, min_similarity, limit))
        else:
            cur.execute("""
                WITH ranked AS (
                    SELECT o.*, e.name as entity_name, 'active' as storage,
                           1 - (o.embedding <=> %s::vector) as similarity
                    FROM observations o
                    LEFT JOIN entities e ON o.entity_id = e.id
                    WHERE o.embedding IS NOT NULL
                )
                SELECT * FROM ranked
                WHERE similarity >= %s
                ORDER BY similarity DESC
                LIMIT %s
            """, (embedding_str, min_similarity, limit))
        
        results = [dict(row) for row in cur.fetchall()]
    finally:
        if conn:
            conn.close()
    
    # Format for JSON
    for r in results:
        if r.get('created_at'):
            r['created_at'] = r['created_at'].isoformat()
        if r.get('embedding'):
            del r['embedding']  # Don't send the full embedding back
        r['similarity'] = round(r['similarity'], 4) if r.get('similarity') else None
    
    return jsonify({
        'query': query,
        'results': results,
        'count': len(results),
        'min_similarity': min_similarity,
        'threshold_applied': True,
        'embedding_source': embedding_source
    })


@app.route('/api/search/similar/<int:obs_id>')
def api_find_similar(obs_id):
    """Find observations similar to a given observation."""
    limit = min(100, max(1, int(request.args.get('limit', 10))))  # Clamp 1-100
    
    with db_connection() as conn:
        cur = conn.cursor()
        
        # Get the source observation's embedding
        cur.execute("SELECT embedding FROM observations WHERE id = %s", (obs_id,))
        row = cur.fetchone()
        
        if not row or not row['embedding']:
            # Try archive
            cur.execute("SELECT embedding FROM observations_archive WHERE id = %s", (obs_id,))
            row = cur.fetchone()
        
        if not row or not row['embedding']:
            return jsonify({'error': 'Observation not found or has no embedding', 'results': []}), 404
        
        embedding = row['embedding']
        
        # Find similar (excluding self)
        cur.execute("""
            SELECT o.*, e.name as entity_name,
                   1 - (o.embedding <=> %s) as similarity
            FROM observations o
            LEFT JOIN entities e ON o.entity_id = e.id
            WHERE o.embedding IS NOT NULL AND o.id != %s
            ORDER BY o.embedding <=> %s
            LIMIT %s
        """, (embedding, obs_id, embedding, limit))
        
        results = [dict(row) for row in cur.fetchall()]
        
        for r in results:
            if r.get('created_at'):
                r['created_at'] = r['created_at'].isoformat()
            if r.get('embedding'):
                del r['embedding']
            r['similarity'] = round(r['similarity'], 4) if r.get('similarity') else None
        
        return jsonify({
            'source_id': obs_id,
            'results': results,
            'count': len(results)
    })


@app.route('/api/timeline')
def api_timeline():
    """Get timeline data for visualization."""
    with db_connection() as conn:
        cur = conn.cursor()
        
        granularity = request.args.get('granularity', 'day')  # day, week, month
        
        if granularity == 'month':
            date_trunc = 'month'
        elif granularity == 'week':
            date_trunc = 'week'
        else:
            date_trunc = 'day'
        
        cur.execute(f"""
            SELECT 
                DATE_TRUNC('{date_trunc}', created_at) as period,
                COUNT(*) as count,
                COUNT(*) FILTER (WHERE importance >= 0.8) as high_importance,
                ARRAY_AGG(DISTINCT observation_type) FILTER (WHERE observation_type IS NOT NULL) as types
            FROM observations
            GROUP BY DATE_TRUNC('{date_trunc}', created_at)
            ORDER BY period DESC
            LIMIT 365
        """)
        
        timeline = []
        for row in cur.fetchall():
            timeline.append({
                'period': row['period'].isoformat() if row['period'] else None,
                'count': row['count'],
                'high_importance': row['high_importance'],
                'types': row['types'] or []
            })
        
        return jsonify({'timeline': timeline, 'granularity': granularity})


@app.route('/api/insights')
def api_insights():
    """Get automated insights about the memory."""
    with db_connection() as conn:
        cur = conn.cursor()
        
        insights = []
        
        # Top co-occurring tags
        cur.execute("""
            WITH tag_pairs AS (
                SELECT t1.tag as tag1, t2.tag as tag2, COUNT(*) as co_count
                FROM (SELECT id, UNNEST(tags) as tag FROM observations WHERE tags IS NOT NULL) t1
                JOIN (SELECT id, UNNEST(tags) as tag FROM observations WHERE tags IS NOT NULL) t2
                ON t1.id = t2.id AND t1.tag < t2.tag
                GROUP BY t1.tag, t2.tag
                HAVING COUNT(*) >= 5
                ORDER BY co_count DESC
                LIMIT 10
            )
            SELECT * FROM tag_pairs
        """)
        tag_correlations = [dict(row) for row in cur.fetchall()]
        if tag_correlations:
            insights.append({
                'type': 'tag_correlation',
                'title': 'Frequently Co-occurring Tags',
                'data': tag_correlations
            })
        
        # Activity by day of week
        cur.execute("""
            SELECT 
                EXTRACT(DOW FROM created_at) as day_of_week,
                COUNT(*) as count
            FROM observations
            GROUP BY EXTRACT(DOW FROM created_at)
            ORDER BY day_of_week
        """)
        day_names = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
        activity_by_day = []
        for row in cur.fetchall():
            activity_by_day.append({
                'day': day_names[int(row['day_of_week'])],
                'count': row['count']
            })
        if activity_by_day:
            insights.append({
                'type': 'activity_pattern',
                'title': 'Activity by Day of Week',
                'data': activity_by_day
            })
        
        # Top focus areas (by tag count this month)
        cur.execute("""
            SELECT tag, COUNT(*) as count
            FROM (
                SELECT UNNEST(tags) as tag 
                FROM observations 
                WHERE tags IS NOT NULL 
                AND created_at > NOW() - INTERVAL '30 days'
            ) t
            GROUP BY tag
            ORDER BY count DESC
            LIMIT 5
        """)
        focus_areas = [dict(row) for row in cur.fetchall()]
        if focus_areas:
            insights.append({
                'type': 'focus_areas',
                'title': 'Top Focus Areas (Last 30 Days)',
                'data': focus_areas
            })
        
        # Recent milestones
        cur.execute("""
            SELECT id, LEFT(observation_text, 150) as preview, created_at, importance
            FROM observations
            WHERE observation_type = 'milestone' OR importance >= 0.9
            ORDER BY created_at DESC
            LIMIT 5
        """)
        milestones = []
        for row in cur.fetchall():
            milestones.append({
                'id': row['id'],
                'preview': row['preview'],
                'created_at': row['created_at'].isoformat() if row['created_at'] else None,
                'importance': row['importance']
            })
        if milestones:
            insights.append({
                'type': 'milestones',
                'title': 'Recent Milestones',
                'data': milestones
            })
    
    return jsonify({'insights': insights})


@app.route('/api/graph/timeline')
def api_graph_timeline():
    """Get graph data with timestamps for time animation."""
    min_observations = int(request.args.get('min_obs', 2))
    
    with db_connection() as conn:
        cur = conn.cursor()
        
        # Get entities with their first observation date
        cur.execute("""
            SELECT e.id, e.name, e.entity_type,
                   COUNT(o.id) as obs_count,
                   MIN(o.created_at) as first_seen,
                   MAX(o.created_at) as last_seen,
                   COALESCE(e.metadata->>'current_focus', '') as current_focus
            FROM entities e
            LEFT JOIN observations o ON o.entity_id = e.id
            GROUP BY e.id, e.name, e.entity_type, e.metadata
            HAVING COUNT(o.id) >= %s
            ORDER BY MIN(o.created_at) ASC
            LIMIT 100
        """, (min_observations,))
        
        entities = [dict(row) for row in cur.fetchall()]
        entity_ids = [e['id'] for e in entities]
        
        if not entity_ids:
            return jsonify({'nodes': [], 'links': [], 'timeRange': None})
        
        # Build nodes with timestamps
        nodes = []
        min_time = None
        max_time = None
        
        for e in entities:
            first_seen = e['first_seen']
            if first_seen:
                if min_time is None or first_seen < min_time:
                    min_time = first_seen
                if max_time is None or first_seen > max_time:
                    max_time = first_seen
            
            nodes.append({
                'id': f"entity_{e['id']}",
                'name': e['name'],
                'type': 'entity',
                'entity_type': e['entity_type'],
                'obs_count': e['obs_count'],
                'first_seen': first_seen.isoformat() if first_seen else None,
                'last_seen': e['last_seen'].isoformat() if e['last_seen'] else None,
                'current_focus': e['current_focus'],
                'size': min(50, 10 + e['obs_count'] * 2)
            })
        
        # Get links with timestamps (when entities first co-occurred)
        cur.execute("""
            WITH entity_tags AS (
                SELECT DISTINCT o.entity_id, UNNEST(o.tags) as tag, MIN(o.created_at) as first_tag
                FROM observations o
                WHERE o.entity_id = ANY(%s) AND o.tags IS NOT NULL
                GROUP BY o.entity_id, UNNEST(o.tags)
            )
            SELECT et1.entity_id as source, et2.entity_id as target,
                   COUNT(DISTINCT et1.tag) as shared_tags,
                   MIN(GREATEST(et1.first_tag, et2.first_tag)) as link_formed
            FROM entity_tags et1
            JOIN entity_tags et2 ON et1.tag = et2.tag AND et1.entity_id < et2.entity_id
            GROUP BY et1.entity_id, et2.entity_id
            HAVING COUNT(DISTINCT et1.tag) >= 1
        """, (entity_ids,))
        
        links = []
        for row in cur.fetchall():
            link_formed = row['link_formed']
            links.append({
                'source': f"entity_{row['source']}",
                'target': f"entity_{row['target']}",
                'type': 'shared_tags',
                'strength': row['shared_tags'],
                'formed_at': link_formed.isoformat() if link_formed else None
            })
    
    return jsonify({
        'nodes': nodes,
        'links': links,
        'timeRange': {
            'min': min_time.isoformat() if min_time else None,
            'max': max_time.isoformat() if max_time else None
        }
    })


@app.route('/api/memories/domain/<path:domain>')
def api_memories_by_domain(domain):
    """Get memories associated with a specific domain for bi-directional sync."""
    limit = min(100, max(1, int(request.args.get('limit', 20))))  # Clamp 1-100
    
    with db_connection() as conn:
        cur = conn.cursor()
        
        # Search for domain in metadata or observation text
        cur.execute("""
            SELECT o.id, o.observation_text, o.observation_type, o.importance,
                   o.tags, o.created_at, e.name as entity_name,
                   o.metadata->>'url' as url
            FROM observations o
            LEFT JOIN entities e ON o.entity_id = e.id
            WHERE o.metadata->>'url' ILIKE %s
               OR o.metadata->>'domain' ILIKE %s
               OR o.observation_text ILIKE %s
            ORDER BY o.created_at DESC
            LIMIT %s
        """, (f'%{domain}%', f'%{domain}%', f'%{domain}%', limit))
        
        memories = []
        for row in cur.fetchall():
            memories.append({
                'id': row['id'],
                'text': row['observation_text'][:300] if row['observation_text'] else '',
                'type': row['observation_type'],
                'importance': row['importance'],
                'tags': row['tags'],
                'created_at': row['created_at'].isoformat() if row['created_at'] else None,
                'entity_name': row['entity_name'],
                'url': row['url']
            })
    
    return jsonify({
        'domain': domain,
        'count': len(memories),
        'memories': memories
    })


@app.route('/api/memories/url')
def api_memories_by_url():
    """Get memories associated with a specific URL - precise matching.
    
    Matching priority:
    1. Exact URL match
    2. URL path prefix match (e.g., github.com/user/repo matches github.com/user/repo/issues/1)
    3. No match (returns empty)
    
    Never matches on domain alone to prevent false positives.
    """
    url = request.args.get('url', '')
    if not url:
        return jsonify({'error': 'URL required'}), 400
    
    limit = min(50, max(1, int(request.args.get('limit', 10))))  # Clamp 1-50
    
    # Parse URL to get components
    try:
        from urllib.parse import urlparse
        parsed = urlparse(url)
        # Normalize: remove trailing slash, lowercase
        normalized_url = f"{parsed.scheme}://{parsed.netloc}{parsed.path.rstrip('/')}".lower()
        # For path prefix matching: domain + path without trailing slash
        url_prefix = f"{parsed.netloc}{parsed.path.rstrip('/')}".lower()
    except:
        return jsonify({'url': url, 'count': 0, 'memories': []})
    
    with db_connection() as conn:
        cur = conn.cursor()
        
        # Query for memories matching this URL
        # Priority 1: Exact URL match (stored URL = current URL)
        # Priority 2: Current URL is a subpage of stored URL (e.g., stored: github.com/user/repo, current: github.com/user/repo/issues/5)
        # Priority 3: Stored URL is a subpage of current URL (less common but valid)
        cur.execute("""
            SELECT o.id, o.observation_text, o.observation_type, o.importance,
                   o.tags, o.created_at, e.name as entity_name,
                   o.metadata->>'url' as url,
                   CASE 
                       WHEN LOWER(o.metadata->>'url') = %s THEN 0
                       WHEN %s LIKE LOWER(o.metadata->>'url') || '%%' THEN 1
                       WHEN LOWER(o.metadata->>'url') LIKE %s || '%%' THEN 2
                       ELSE 3
                   END as match_priority
            FROM observations o
            LEFT JOIN entities e ON o.entity_id = e.id
            WHERE LOWER(o.metadata->>'url') = %s
               OR %s LIKE LOWER(o.metadata->>'url') || '%%'
               OR LOWER(o.metadata->>'url') LIKE %s || '%%'
            ORDER BY match_priority, o.created_at DESC
            LIMIT %s
        """, (normalized_url, normalized_url, url_prefix, normalized_url, normalized_url, url_prefix, limit))
        
        memories = []
        for row in cur.fetchall():
            memories.append({
                'id': row['id'],
                'text': row['observation_text'][:300] if row['observation_text'] else '',
                'type': row['observation_type'],
                'importance': row['importance'],
                'tags': row['tags'],
                'created_at': row['created_at'].isoformat() if row['created_at'] else None,
                'entity_name': row['entity_name'],
                'url': row['url']
            })
    
    return jsonify({
        'url': url,
        'count': len(memories),
        'memories': memories,
        'matching': 'exact' if memories and memories[0].get('url', '').lower() == normalized_url else 'prefix' if memories else 'none'
    })


if __name__ == '__main__':
    print(f"""
╔══════════════════════════════════════════════════════════════╗
║           🧠 LONGTERM MEMORY DASHBOARD                       ║
║                                                              ║
║   Database: {DB_NAME}@{DB_HOST}:{DB_PORT}                    
║   User: {DB_USER}                                            
║                                                              ║
║   Access at: http://localhost:5555                           ║
╚══════════════════════════════════════════════════════════════╝
    """)
    app.run(host='127.0.0.1', port=5555, debug=False)
