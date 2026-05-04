from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from typing import List, Dict, Any
from app.strength_checker import PasswordStrengthChecker
from app.db import init_db, save_check, get_recent_checks
import os
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Password Strength Checker Agent")

# Initialize checker
checker = PasswordStrengthChecker()

# Initialize database on startup with error handling
@app.on_event("startup")
async def startup_event():
    try:
        init_db()
        logger.info("Application started successfully")
    except Exception as e:
        logger.error(f"Failed to initialize database: {e}")
        # Don't crash the app, just log the error
        # The app will still work but without persistence

class PasswordRequest(BaseModel):
    password: str = Field(..., min_length=1, max_length=128)

class PasswordResponse(BaseModel):
    password: str
    strength: str
    suggestions: List[str]
    score: int

class HistoryResponse(BaseModel):
    checks: List[Dict[str, Any]]

@app.post("/check", response_model=PasswordResponse)
async def check_password(request: PasswordRequest):
    """
    Check password strength and get improvement suggestions
    """
    password = request.password
    
    # Check strength
    strength, score, suggestions = checker.check_strength(password)
    
    # Hash and store (try, but don't fail if DB fails)
    try:
        password_hash = checker.hash_password(password)
        save_check(password_hash, strength, suggestions, score)
    except Exception as e:
        logger.warning(f"Could not save to database: {e}")
    
    # Return response (mask password for security)
    masked_password = password[:2] + '*' * (len(password) - 4) + password[-2:] if len(password) > 4 else '*' * len(password)
    
    return PasswordResponse(
        password=masked_password,
        strength=strength,
        suggestions=suggestions,
        score=score
    )

@app.get("/history", response_model=HistoryResponse)
async def get_history(limit: int = 10):
    """
    Get recent password check history
    """
    checks = get_recent_checks(limit)
    return HistoryResponse(checks=checks)

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)