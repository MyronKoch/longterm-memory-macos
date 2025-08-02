#!/usr/bin/env python3
"""
Backfill tags, observation_type, and importance for legacy observations.
Uses pattern matching and keyword extraction to enrich old data.

Run with: python3 backfill_metadata.py [--dry-run] [--limit N]
"""

import os
import re
import json
import argparse
import psycopg2
from psycopg2.extras import RealDictCursor
from collections import Counter

# Database config
DB_NAME = os.environ.get('LONGTERM_MEMORY_DB', 'longterm_memory')
DB_USER = os.environ.get('LONGTERM_MEMORY_USER', os.environ.get('USER'))
DB_HOST = os.environ.get('LONGTERM_MEMORY_HOST', 'localhost')
DB_PORT = os.environ.get('LONGTERM_MEMORY_PORT', '5432')

# Observation type patterns
TYPE_PATTERNS = {
    'technical_achievement': [
        r'successfully|completed|fixed|resolved|working|deployed|installed|configured',
        r'migration complete|now works|bug fixed|issue resolved',
    ],
    'milestone': [
        r'milestone|launched|released|shipped|v\d+\.\d+|version \d+',
        r'first time|breakthrough|achievement',
    ],
    'insight': [
        r'realized|discovered|learned|understanding|insight|key finding',
        r'important:|note:|remember:',
    ],
    'project_update': [
        r'progress|update|status|working on|building|developing',
        r'added|created|implemented|integrated',
    ],
    'research': [
        r'research|investigating|exploring|analyzing|studying',
        r'paper|article|documentation|spec',
    ],
    'decision': [
        r'decided|decision|chose|selected|going with|will use',
        r'strategy|approach|plan',
    ],
    'problem': [
        r'issue|problem|error|bug|failed|broken|not working',
        r'trouble|stuck|blocker',
    ],
    'reference': [
        r'reference|documentation|guide|tutorial|how to',
        r'url:|link:|see:|docs:',
    ],
}

# Tag extraction patterns
TAG_PATTERNS = {
    # Technologies
    'python': r'\bpython\b',
    'javascript': r'\b(javascript|js|node\.?js|typescript|ts)\b',
    'postgresql': r'\b(postgres|postgresql|psql|pg_)\b',
    'docker': r'\bdocker\b',
    'git': r'\bgit(hub|lab)?\b',
    'mcp': r'\bmcp\b',
    'blockchain': r'\b(blockchain|web3|crypto|ethereum|bitcoin|solana)\b',
    'ai': r'\b(ai|llm|gpt|claude|anthropic|openai|embedding|vector)\b',
    'react': r'\breact\b',
    'flask': r'\bflask\b',
    'vue': r'\bvue\b',
    
    # Concepts
    'api': r'\bapi\b',
    'database': r'\b(database|db|sql)\b',
    'testing': r'\b(test|testing|unittest|pytest)\b',
    'deployment': r'\b(deploy|deployment|production|staging)\b',
    'configuration': r'\b(config|configuration|setup|settings)\b',
    'security': r'\b(security|auth|authentication|oauth|jwt)\b',
    'performance': r'\b(performance|optimization|speed|latency)\b',
    
    # Project-specific
    'ccxt': r'\bccxt\b',
    'wallet': r'\bwallet\b',
    'voice': r'\b(voice|speech|audio|pipecat)\b',
    'memory': r'\b(memory|semantic|embedding|longterm)\b',
    'multi-agent': r'\b(multi-?agent|agent|tmux)\b',
}

# Importance signals
HIGH_IMPORTANCE_SIGNALS = [
    r'important|critical|crucial|essential|key|major',
    r'breakthrough|milestone|achievement|success',
    r'production|deployed|released|shipped',
    r'decision|strategy|architecture',
]

MEDIUM_IMPORTANCE_SIGNALS = [
    r'completed|finished|done|working',
    r'fixed|resolved|solved',
    r'learned|discovered|realized',
]

LOW_IMPORTANCE_SIGNALS = [
    r'testing|trying|experimenting',
    r'minor|small|quick',
    r'debug|troubleshoot',
]


def get_db():
    return psycopg2.connect(
        dbname=DB_NAME,
        user=DB_USER,
        host=DB_HOST,
        port=DB_PORT,
        cursor_factory=RealDictCursor
    )


def infer_observation_type(text):
    """Infer observation type from text patterns."""
    text_lower = text.lower()
    
    scores = {}
    for obs_type, patterns in TYPE_PATTERNS.items():
        score = 0
        for pattern in patterns:
            matches = len(re.findall(pattern, text_lower, re.IGNORECASE))
            score += matches
        if score > 0:
            scores[obs_type] = score
    
    if scores:
        return max(scores, key=scores.get)
    return 'note'  # Default


def extract_tags(text):
    """Extract tags from text using patterns."""
    text_lower = text.lower()
    tags = []
    
    for tag, pattern in TAG_PATTERNS.items():
        if re.search(pattern, text_lower, re.IGNORECASE):
            tags.append(tag)
    
    # Limit to top 10 most relevant
    return tags[:10]


def calculate_importance(text, entity_name=None):
    """Calculate importance score 0-1 based on signals."""
    text_lower = text.lower()
    score = 0.5  # Base score
    
    # High importance signals
    for pattern in HIGH_IMPORTANCE_SIGNALS:
        if re.search(pattern, text_lower, re.IGNORECASE):
            score += 0.15
    
    # Medium importance signals  
    for pattern in MEDIUM_IMPORTANCE_SIGNALS:
        if re.search(pattern, text_lower, re.IGNORECASE):
            score += 0.08
    
    # Low importance signals (reduce slightly)
    for pattern in LOW_IMPORTANCE_SIGNALS:
        if re.search(pattern, text_lower, re.IGNORECASE):
            score -= 0.05
    
    # Length bonus (longer = more detailed = more important)
    if len(text) > 500:
        score += 0.1
    elif len(text) > 200:
        score += 0.05
    
    # Entity mention bonus - boost for user identity entities
    # Customize this list with your own entity names
    user_entities = os.getenv('LONGTERM_MEMORY_USER_ENTITIES', '').lower().split(',')
    if entity_name and entity_name.lower() in user_entities:
        score += 0.1
    
    # Clamp to 0-1
    return max(0.1, min(1.0, score))


def process_observation(obs, dry_run=False):
    """Process a single observation and return enrichment data."""
    text = obs['observation_text'] or ''
    entity_name = obs.get('entity_name', '')
    
    # Skip if already has metadata
    if obs.get('tags') and len(obs['tags']) > 0:
        return None
    
    obs_type = infer_observation_type(text)
    tags = extract_tags(text)
    importance = calculate_importance(text, entity_name)
    
    return {
        'id': obs['id'],
        'observation_type': obs_type,
        'tags': tags,
        'importance': round(importance, 2),
    }


def backfill_observations(table='observations', dry_run=False, limit=None):
    """Backfill metadata for observations in a table."""
    conn = get_db()
    cur = conn.cursor()
    
    # Get observations without tags
    query = f"""
        SELECT o.id, o.observation_text, e.name as entity_name,
               o.tags, o.observation_type, o.importance
        FROM {table} o
        LEFT JOIN entities e ON o.entity_id = e.id
        WHERE o.tags IS NULL OR array_length(o.tags, 1) IS NULL
        ORDER BY o.id
    """
    if limit:
        query += f" LIMIT {limit}"
    
    cur.execute(query)
    observations = cur.fetchall()
    
    print(f"\n📊 Processing {len(observations)} observations from {table}...")
    
    updates = []
    type_counts = Counter()
    tag_counts = Counter()
    
    for obs in observations:
        result = process_observation(obs, dry_run)
        if result:
            updates.append(result)
            type_counts[result['observation_type']] += 1
            for tag in result['tags']:
                tag_counts[tag] += 1
    
    print(f"\n📈 Analysis complete:")
    print(f"   Observations to update: {len(updates)}")
    print(f"\n   Types detected:")
    for t, c in type_counts.most_common(10):
        print(f"      {t}: {c}")
    print(f"\n   Top tags:")
    for t, c in tag_counts.most_common(15):
        print(f"      {t}: {c}")
    
    if dry_run:
        print(f"\n🔍 DRY RUN - No changes made")
        # Show sample
        print(f"\n   Sample updates:")
        for u in updates[:5]:
            print(f"      ID {u['id']}: type={u['observation_type']}, importance={u['importance']}, tags={u['tags'][:5]}")
    else:
        print(f"\n💾 Applying updates...")
        for i, u in enumerate(updates):
            cur.execute(f"""
                UPDATE {table}
                SET observation_type = %s,
                    importance = %s,
                    tags = %s
                WHERE id = %s
            """, (u['observation_type'], u['importance'], u['tags'], u['id']))
            
            if (i + 1) % 500 == 0:
                print(f"   Updated {i + 1}/{len(updates)}...")
                conn.commit()
        
        conn.commit()
        print(f"   ✅ Updated {len(updates)} observations")
    
    conn.close()
    return len(updates)


def main():
    parser = argparse.ArgumentParser(description='Backfill observation metadata')
    parser.add_argument('--dry-run', action='store_true', help='Preview without making changes')
    parser.add_argument('--limit', type=int, help='Limit number of observations to process')
    parser.add_argument('--archive', action='store_true', help='Also process archived observations')
    args = parser.parse_args()
    
    print("🧠 Longterm Memory Metadata Backfill")
    print("=" * 50)
    
    # Process active observations
    active_count = backfill_observations('observations', args.dry_run, args.limit)
    
    # Process archive if requested
    archive_count = 0
    if args.archive:
        archive_count = backfill_observations('observations_archive', args.dry_run, args.limit)
    
    print(f"\n" + "=" * 50)
    print(f"✅ Complete!")
    print(f"   Active: {active_count} observations enriched")
    if args.archive:
        print(f"   Archive: {archive_count} observations enriched")
    
    if args.dry_run:
        print(f"\n💡 Run without --dry-run to apply changes")


if __name__ == '__main__':
    main()
