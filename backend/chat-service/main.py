from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import httpx
import os
import logging
from contextlib import asynccontextmanager

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class Message(BaseModel):
    role: str
    content: str

class ChatRequest(BaseModel):
    session_id: str
    message: str
    messages: Optional[List[Message]] = []

class ChatResponse(BaseModel):
    response: str
    session_id: str

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("Chat service starting up...")
    yield
    # Shutdown
    logger.info("Chat service shutting down...")

app = FastAPI(
    title="Chat Service",
    description="Service for handling OpenAI chat completions",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your frontend domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Environment variables
OPENAI_ENDPOINT = os.getenv("OPENAI_ENDPOINT")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OPENAI_DEPLOYMENT = os.getenv("OPENAI_DEPLOYMENT", "gpt-4o-mini")
SESSION_SERVICE_URL = os.getenv("SESSION_SERVICE_URL", "http://session-service:8001")

if not OPENAI_ENDPOINT or not OPENAI_API_KEY:
    raise ValueError("OPENAI_ENDPOINT and OPENAI_API_KEY environment variables must be set")

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "chat-service"}

@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    try:
        # Get conversation history from session service
        async with httpx.AsyncClient() as client:
            history_response = await client.get(
                f"{SESSION_SERVICE_URL}/sessions/{request.session_id}/messages"
            )
            
            if history_response.status_code == 200:
                history_data = history_response.json()
                conversation_history = history_data.get("messages", [])
            else:
                conversation_history = []

        # Prepare messages for OpenAI
        messages = []
        
        # Add system message
        messages.append({
            "role": "system", 
            "content": "You are a helpful assistant. Keep your responses concise and helpful."
        })
        
        # Add conversation history
        for msg in conversation_history:
            messages.append({
                "role": msg["role"],
                "content": msg["content"]
            })
        
        # Add new user message
        messages.append({
            "role": "user",
            "content": request.message
        })

        # Call Azure OpenAI
        headers = {
            "Content-Type": "application/json",
            "api-key": OPENAI_API_KEY
        }
        
        payload = {
            "messages": messages,
            "max_tokens": 500,
            "temperature": 0.7
        }

        async with httpx.AsyncClient(timeout=30.0) as client:
            openai_response = await client.post(
                f"{OPENAI_ENDPOINT}/openai/deployments/{OPENAI_DEPLOYMENT}/chat/completions?api-version=2024-08-01-preview",
                headers=headers,
                json=payload
            )

        if openai_response.status_code != 200:
            logger.error(f"OpenAI API error: {openai_response.status_code} - {openai_response.text}")
            raise HTTPException(status_code=500, detail="Failed to get response from OpenAI")

        response_data = openai_response.json()
        assistant_message = response_data["choices"][0]["message"]["content"]

        # Save both user and assistant messages to session service
        async with httpx.AsyncClient() as client:
            # Save user message
            await client.post(
                f"{SESSION_SERVICE_URL}/sessions/{request.session_id}/messages",
                json={"role": "user", "content": request.message}
            )
            
            # Save assistant message
            await client.post(
                f"{SESSION_SERVICE_URL}/sessions/{request.session_id}/messages",
                json={"role": "assistant", "content": assistant_message}
            )

        return ChatResponse(
            response=assistant_message,
            session_id=request.session_id
        )

    except httpx.TimeoutException:
        logger.error("Timeout when calling OpenAI API")
        raise HTTPException(status_code=504, detail="Request timeout")
    except Exception as e:
        logger.error(f"Error in chat endpoint: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
