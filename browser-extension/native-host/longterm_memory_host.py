#!/usr/bin/python3
"""
Native messaging host for Longterm Memory Chrome extension.
Bridges Chrome extension to local PostgreSQL database.

Updated: November 2025
- Uses new metadata columns (observation_type, importance, metadata, tags)
- Better category/tag handling
- Improved error logging
"""

import sys
import json
import struct
import os
from datetime import datetime
from urllib.parse import urlparse

# Configuration
DB_NAME = os.environ.get('LONGTERM_MEMORY_DB', 'longterm_memory')
DB_USER = os.environ.get('LONGTERM_MEMORY_USER', os.environ.get('USER'))
DB_HOST = os.environ.get('LONGTERM_MEMORY_HOST', 'localhost')
DB_PORT = os.environ.get('LONGTERM_MEMORY_PORT', '5432')

# Security limits
MAX_MESSAGE_SIZE = 1024 * 1024  # 1 MB max message size

LOG_FILE = '/tmp/longterm_memory_host.log'

def log(message):
    """Write to log file for debugging."""
    try:
        with open(LOG_FILE, 'a') as f:
            f.write(f'{datetime.now().isoformat()} - {message}\n')
    except:
        pass

log('Native host starting')
log(f'Python: {sys.executable}')
log(f'DB: {DB_NAME}@{DB_HOST}:{DB_PORT} as {DB_USER}')

try:
    import psycopg2
    log('psycopg2 imported successfully')
except Exception as e:
    log(f'ERROR importing psycopg2: {e}')
    sys.exit(1)


def read_message():
    """Read a message from Chrome extension."""
    raw_length = sys.stdin.buffer.read(4)
    if not raw_length:
        return None
    message_length = struct.unpack('=I', raw_length)[0]
    
    # Security: reject oversized messages
    if message_length > MAX_MESSAGE_SIZE:
        log(f'ERROR: Message too large ({message_length} bytes, max {MAX_MESSAGE_SIZE})')
        return {'error': 'Message exceeds maximum size limit'}
    
    message = sys.stdin.buffer.read(message_length).decode('utf-8')
    return json.loads(message)


def send_message(message):
    """Send a message to Chrome extension."""
    encoded_message = json.dumps(message).encode('utf-8')
    sys.stdout.buffer.write(struct.pack('=I', len(encoded_message)))
    sys.stdout.buffer.write(encoded_message)
    sys.stdout.buffer.flush()


def get_db_connection():
    """Get PostgreSQL database connection."""
    return psycopg2.connect(
        dbname=DB_NAME,
        user=DB_USER,
        host=DB_HOST,
        port=DB_PORT
    )


def map_category_to_observation_type(category, capture_type):
    """Map browser extension category to observation_type."""
    category_map = {
        'documentation': 'reference',
        'reference': 'reference',
        'research': 'research',
        'article': 'article',
        'news': 'news',
        'code': 'technical',
        'social': 'social',
        'personal': 'personal',
    }
    
    # If it's a note or selection, prioritize that
    if capture_type == 'note':
        return 'note'
    elif capture_type == 'selection':
        return 'excerpt'
    elif capture_type == 'page':
        return 'page_capture'
    
    return category_map.get(category, 'web_capture')


def calculate_importance(capture_type, has_notes, tags):
    """Calculate default importance based on capture context."""
    base = 0.5
    
    # User added notes = more important
    if has_notes:
        base += 0.2
    
    # Explicit tags = user cares about this
    if tags and len(tags) > 0:
        base += 0.1
    
    # Full page captures slightly less important than curated notes
    if capture_type == 'page':
        base -= 0.1
    
    # Clamp to 0-1 range
    return max(0.0, min(1.0, base))


def get_or_create_entity(cursor, url, title, entity_metadata=None):
    """Get or create entity for the URL's domain."""
    parsed = urlparse(url)
    domain = parsed.netloc or parsed.path.split('/')[0]
    
    if not domain:
        domain = 'unknown'

    # Try to find existing entity
    cursor.execute(
        "SELECT id FROM entities WHERE name = %s",
        (domain,)
    )
    result = cursor.fetchone()

    if result:
        entity_id = result[0]
        # Update observation_count
        cursor.execute(
            "UPDATE entities SET observation_count = observation_count + 1 WHERE id = %s",
            (entity_id,)
        )
        return entity_id

    # Prepare entity metadata
    meta = {
        'first_title': title,
        'created_via': 'browser_extension',
        'first_captured': datetime.now().isoformat()
    }
    if entity_metadata:
        meta.update(entity_metadata)

    # Create new entity
    cursor.execute(
        """
        INSERT INTO entities (name, entity_type, source_type, observation_count, metadata)
        VALUES (%s, %s, %s, %s, %s)
        RETURNING id
        """,
        (domain, 'website', 'browser_extension', 1, json.dumps(meta))
    )
    return cursor.fetchone()[0]


def save_observation(data):
    """Save observation to database using new metadata columns."""
    try:
        log(f'Saving observation: {json.dumps(data)[:200]}...')
        
        conn = get_db_connection()
        cursor = conn.cursor()

        # Extract data
        content = data.get('content', '')
        url = data.get('url', '')
        title = data.get('title', '')
        capture_type = data.get('type', 'unknown')
        metadata_input = data.get('metadata', {})
        
        # Extract category and tags from metadata
        category = metadata_input.get('category', 'auto')
        tags = metadata_input.get('tags', [])
        
        # Ensure tags is a list
        if isinstance(tags, str):
            tags = [t.strip() for t in tags.split(',') if t.strip()]
        
        # Add automatic tags based on category
        if category and category != 'auto':
            if category not in tags:
                tags.append(category)
        
        # Add 'browser' tag to identify source
        if 'browser' not in tags:
            tags.append('browser')

        # Get or create entity
        entity_id = get_or_create_entity(cursor, url, title)

        # Get next observation index for this entity
        cursor.execute(
            "SELECT COALESCE(MAX(observation_index), 0) + 1 FROM observations WHERE entity_id = %s",
            (entity_id,)
        )
        observation_index = cursor.fetchone()[0]

        # Build observation text (cleaner format)
        observation_parts = []
        
        # Date prefix for consistency with other observations
        date_str = datetime.now().strftime('%B %d, %Y')
        
        if capture_type == 'note':
            observation_parts.append(f'{date_str}: NOTE from {title}')
        elif capture_type == 'selection':
            observation_parts.append(f'{date_str}: EXCERPT from {title}')
        elif capture_type == 'page':
            observation_parts.append(f'{date_str}: PAGE CAPTURE - {title}')
        else:
            observation_parts.append(f'{date_str}: {title}')
        
        observation_parts.append(f'URL: {url}')
        observation_parts.append('')  # Empty line
        observation_parts.append(content)
        
        observation_text = '\n'.join(observation_parts)

        # Map to observation_type
        observation_type = map_category_to_observation_type(category, capture_type)
        
        # Calculate importance
        has_notes = capture_type in ('note', 'selection')
        importance = calculate_importance(capture_type, has_notes, tags)
        
        # Build metadata JSONB
        obs_metadata = {
            'url': url,
            'domain': urlparse(url).netloc,
            'category': category,
            'capture_type': capture_type,
            'captured_at': datetime.now().isoformat(),
        }
        
        # Add any extra metadata from the extension
        for key in ['captured_at']:
            if key in metadata_input:
                obs_metadata[key] = metadata_input[key]

        # Insert observation with new columns
        cursor.execute(
            """
            INSERT INTO observations (
                entity_id, 
                observation_text, 
                observation_index, 
                source_type,
                observation_type,
                importance,
                metadata,
                tags
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id
            """,
            (
                entity_id, 
                observation_text, 
                observation_index, 
                'browser_extension',
                observation_type,
                importance,
                json.dumps(obs_metadata),
                tags
            )
        )

        observation_id = cursor.fetchone()[0]

        conn.commit()
        cursor.close()
        conn.close()

        log(f'Saved observation {observation_id} (type: {observation_type}, importance: {importance})')

        return {
            'success': True,
            'observation_id': observation_id,
            'entity_id': entity_id,
            'observation_type': observation_type,
            'importance': importance,
            'tags': tags,
            'message': 'Saved to longterm memory'
        }

    except Exception as e:
        log(f'ERROR saving observation: {e}')
        return {
            'success': False,
            'error': str(e)
        }


def main():
    """Main loop for native messaging."""
    log('Entering main loop')
    
    while True:
        try:
            message = read_message()
            if message is None:
                log('No message received, exiting')
                break

            log(f'Received message: {message.get("action")}')
            action = message.get('action')

            if action == 'save':
                response = save_observation(message.get('data', {}))
                send_message(response)
            elif action == 'ping':
                send_message({'success': True, 'message': 'pong'})
            else:
                send_message({
                    'success': False,
                    'error': f'Unknown action: {action}'
                })
        except Exception as e:
            log(f'ERROR in main loop: {e}')
            send_message({
                'success': False,
                'error': str(e)
            })


if __name__ == '__main__':
    main()
