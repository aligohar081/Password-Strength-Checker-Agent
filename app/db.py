import sqlite3
import json
from datetime import datetime
from typing import List, Dict, Any
import os
import logging

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Get database path from environment or use default
DB_PATH = os.getenv('DB_PATH', '/app/data/password_checks.db')
logger.info(f"Database path: {DB_PATH}")

def get_db_connection():
    """Create database connection"""
    try:
        # Ensure directory exists
        db_dir = os.path.dirname(DB_PATH)
        if db_dir and not os.path.exists(db_dir):
            os.makedirs(db_dir, exist_ok=True)
            logger.info(f"Created database directory: {db_dir}")
        
        conn = sqlite3.connect(DB_PATH, timeout=10)
        conn.row_factory = sqlite3.Row
        return conn
    except Exception as e:
        logger.error(f"Error connecting to database: {e}")
        raise

def init_db():
    """Initialize database table"""
    try:
        conn = get_db_connection()
        conn.execute('''
            CREATE TABLE IF NOT EXISTS password_checks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                password_hash TEXT NOT NULL,
                strength TEXT NOT NULL,
                suggestions TEXT NOT NULL,
                score INTEGER NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        conn.commit()
        
        # Verify table was created
        cursor = conn.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='password_checks'")
        if cursor.fetchone():
            logger.info("Database initialized successfully")
        else:
            logger.error("Failed to create password_checks table")
            
        conn.close()
    except Exception as e:
        logger.error(f"Error initializing database: {e}")
        raise

def save_check(password_hash: str, strength: str, suggestions: List[str], score: int):
    """Save password check to database"""
    try:
        conn = get_db_connection()
        conn.execute(
            'INSERT INTO password_checks (password_hash, strength, suggestions, score) VALUES (?, ?, ?, ?)',
            (password_hash, strength, json.dumps(suggestions), score)
        )
        conn.commit()
        conn.close()
        logger.debug(f"Saved check for hash: {password_hash[:10]}...")
    except Exception as e:
        logger.error(f"Error saving check: {e}")
        # Don't raise - allow the API to still return the strength result
        # even if database save fails

def get_recent_checks(limit: int = 10) -> List[Dict[str, Any]]:
    """Get recent password checks"""
    try:
        conn = get_db_connection()
        cursor = conn.execute(
            'SELECT id, password_hash, strength, suggestions, score, created_at FROM password_checks ORDER BY created_at DESC LIMIT ?',
            (limit,)
        )
        rows = cursor.fetchall()
        conn.close()
        
        return [
            {
                'id': row['id'],
                'password_hash': row['password_hash'],
                'strength': row['strength'],
                'suggestions': json.loads(row['suggestions']),
                'score': row['score'],
                'created_at': row['created_at']
            }
            for row in rows
        ]
    except Exception as e:
        logger.error(f"Error getting recent checks: {e}")
        return []