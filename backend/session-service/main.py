from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import redis.asyncio as redis
import json
import os
import logging
from datetime import datetime, timedelta
from contextlib import asynccontextmanager

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class Message(BaseModel):
    role: str
    content: str
    timestamp: Optional[str] = None

class MessageResponse(BaseModel):
    messages: List[Message]
    session_id: str
    total_messages: int

class SessionInfo(BaseModel):
    session_id: str
    message_count: int
    last_activity: Optional[str] = None

# Global Redis connection
redis_client = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global redis_client
    # Startup
    logger.info("Session service starting up...")
    
    # Initialize Redis connection
    redis_host = os.getenv("REDIS_HOST", "localhost")
    redis_port = int(os.getenv("REDIS_PORT", "6379"))
    redis_password = os.getenv("REDIS_PASSWORD")
    redis_ssl = os.getenv("REDIS_SSL", "true").lower() == "true"
    
    try:
        redis_client = redis.Redis(
            host=redis_host,
            port=redis_port,
            password=redis_password,
            ssl=redis_ssl,
            ssl_cert_reqs=None,
            decode_responses=True
        )
        
        # Test connection
        await redis_client.ping()
        logger.info("Successfully connected to Redis")
        
    except Exception as e:
        logger.error(f"Failed to connect to Redis: {str(e)}")
        raise e
    
    yield
    
    # Shutdown
    if redis_client:
        await redis_client.close()
    logger.info("Session service shutting down...")

app = FastAPI(
    title="Session Service",
    description="Service for managing chat sessions and Redis operations",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Constants
MAX_MESSAGES_PER_SESSION = 20
SESSION_EXPIRY_HOURS = 24

def get_redis_client():
    if redis_client is None:
        raise HTTPException(status_code=500, detail="Redis connection not available")
    return redis_client

@app.get("/health")
async def health_check():
    try:
        client = get_redis_client()
        await client.ping()
        return {"status": "healthy", "service": "session-service", "redis": "connected"}
    except Exception as e:
        return {"status": "unhealthy", "service": "session-service", "redis": f"error: {str(e)}"}

@app.get("/sessions/{session_id}/messages", response_model=MessageResponse)
async def get_session_messages(session_id: str):
    try:
        client = get_redis_client()
        
        # Get messages from Redis list
        messages_data = await client.lrange(f"session:{session_id}:messages", 0, -1)
        
        messages = []
        for msg_data in messages_data:
            try:
                msg_dict = json.loads(msg_data)
                messages.append(Message(**msg_dict))
            except json.JSONDecodeError:
                logger.warning(f"Failed to parse message data: {msg_data}")
                continue
        
        # Update last activity
        await client.setex(
            f"session:{session_id}:last_activity",
            timedelta(hours=SESSION_EXPIRY_HOURS),
            datetime.utcnow().isoformat()
        )
        
        return MessageResponse(
            messages=messages,
            session_id=session_id,
            total_messages=len(messages)
        )
        
    except Exception as e:
        logger.error(f"Error getting session messages: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to get session messages: {str(e)}")

@app.post("/sessions/{session_id}/messages")
async def add_message_to_session(session_id: str, message: Message):
    try:
        client = get_redis_client()
        
        # Add timestamp if not provided
        if not message.timestamp:
            message.timestamp = datetime.utcnow().isoformat()
        
        # Convert message to JSON
        message_json = json.dumps(message.dict())
        
        # Add message to Redis list (left push to maintain order)
        await client.lpush(f"session:{session_id}:messages", message_json)
        
        # Trim list to keep only last MAX_MESSAGES_PER_SESSION messages
        await client.ltrim(f"session:{session_id}:messages", 0, MAX_MESSAGES_PER_SESSION - 1)
        
        # Set expiry for the messages list
        await client.expire(f"session:{session_id}:messages", timedelta(hours=SESSION_EXPIRY_HOURS))
        
        # Update last activity
        await client.setex(
            f"session:{session_id}:last_activity",
            timedelta(hours=SESSION_EXPIRY_HOURS),
            datetime.utcnow().isoformat()
        )
        
        # Update message count
        message_count = await client.llen(f"session:{session_id}:messages")
        await client.setex(
            f"session:{session_id}:count",
            timedelta(hours=SESSION_EXPIRY_HOURS),
            str(message_count)
        )
        
        return {"status": "success", "message": "Message added to session", "session_id": session_id}
        
    except Exception as e:
        logger.error(f"Error adding message to session: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to add message to session: {str(e)}")

@app.get("/sessions/{session_id}/info", response_model=SessionInfo)
async def get_session_info(session_id: str):
    try:
        client = get_redis_client()
        
        # Get message count
        message_count = await client.llen(f"session:{session_id}:messages")
        
        # Get last activity
        last_activity = await client.get(f"session:{session_id}:last_activity")
        
        return SessionInfo(
            session_id=session_id,
            message_count=message_count,
            last_activity=last_activity
        )
        
    except Exception as e:
        logger.error(f"Error getting session info: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to get session info: {str(e)}")

@app.delete("/sessions/{session_id}")
async def delete_session(session_id: str):
    try:
        client = get_redis_client()
        
        # Delete all session-related keys
        keys_to_delete = [
            f"session:{session_id}:messages",
            f"session:{session_id}:last_activity",
            f"session:{session_id}:count"
        ]
        
        deleted_count = await client.delete(*keys_to_delete)
        
        return {
            "status": "success", 
            "message": f"Session deleted", 
            "session_id": session_id,
            "deleted_keys": deleted_count
        }
        
    except Exception as e:
        logger.error(f"Error deleting session: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to delete session: {str(e)}")

@app.get("/sessions")
async def list_active_sessions():
    try:
        client = get_redis_client()
        
        # Get all session keys
        session_keys = await client.keys("session:*:last_activity")
        
        sessions = []
        for key in session_keys:
            session_id = key.split(":")[1]
            last_activity = await client.get(key)
            message_count = await client.llen(f"session:{session_id}:messages")
            
            sessions.append({
                "session_id": session_id,
                "message_count": message_count,
                "last_activity": last_activity
            })
        
        return {"sessions": sessions, "total": len(sessions)}
        
    except Exception as e:
        logger.error(f"Error listing sessions: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to list sessions: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
