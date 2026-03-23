"""
FastAPI Proxy para TCH Julia Server

Este servidor actúa como proxy entre el frontend Expo
y el servidor Julia TCH. Permite:
- Iniciar/detener el servidor Julia
- Proxy de requests a Julia
- WebSocket para terminal en tiempo real
"""

from fastapi import FastAPI, APIRouter, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.responses import JSONResponse
from dotenv import load_dotenv
from starlette.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient
import os
import logging
import subprocess
import asyncio
import httpx
from pathlib import Path
from pydantic import BaseModel
from typing import Optional, Dict, Any
from datetime import datetime
import json

ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / '.env')

# MongoDB connection
mongo_url = os.environ.get('MONGO_URL', 'mongodb://localhost:27017')
client = AsyncIOMotorClient(mongo_url)
db = client[os.environ.get('DB_NAME', 'tch_database')]

# Julia server config
JULIA_PORT = 8002
JULIA_URL = f"http://localhost:{JULIA_PORT}"
julia_process = None

app = FastAPI(title="TCH Terminal Server")
api_router = APIRouter(prefix="/api")

# Logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("TCH")

# Models
class InputRequest(BaseModel):
    input: str

class TCHState(BaseModel):
    session_id: str
    state: str
    mood: str
    drive: float
    cycles: int
    env_vars: Dict[str, str]

# Julia process management
async def start_julia_server():
    """Iniciar servidor Julia en background."""
    global julia_process
    
    if julia_process is not None:
        logger.info("Julia server already running")
        return True
    
    try:
        julia_path = "/root/.juliaup/bin/julia"
        server_path = "/app/backend/julia/server.jl"
        
        env = os.environ.copy()
        env["PATH"] = f"/root/.juliaup/bin:{env.get('PATH', '')}"
        
        julia_process = subprocess.Popen(
            [julia_path, server_path, str(JULIA_PORT)],
            cwd="/app/backend/julia",
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        
        logger.info(f"Starting Julia server on port {JULIA_PORT}...")
        
        # Wait for server to be ready
        for i in range(60):  # Wait up to 60 seconds
            await asyncio.sleep(1)
            try:
                async with httpx.AsyncClient() as client:
                    response = await client.get(f"{JULIA_URL}/", timeout=2.0)
                    if response.status_code == 200:
                        logger.info("Julia server is ready!")
                        return True
            except:
                if i % 10 == 0:
                    logger.info(f"Waiting for Julia server... ({i}s)")
        
        logger.error("Julia server failed to start in time")
        return False
        
    except Exception as e:
        logger.error(f"Failed to start Julia: {e}")
        return False

async def stop_julia_server():
    """Detener servidor Julia."""
    global julia_process
    if julia_process:
        julia_process.terminate()
        julia_process = None
        logger.info("Julia server stopped")

async def proxy_to_julia(method: str, path: str, body: dict = None) -> dict:
    """Proxy request a Julia server."""
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            url = f"{JULIA_URL}{path}"
            
            if method == "GET":
                response = await client.get(url)
            elif method == "POST":
                response = await client.post(url, json=body)
            else:
                raise HTTPException(400, f"Method {method} not supported")
            
            return response.json()
    except httpx.ConnectError:
        # Julia not running, try to start it
        logger.warning("Julia server not responding, attempting to start...")
        started = await start_julia_server()
        if started:
            return await proxy_to_julia(method, path, body)
        raise HTTPException(503, "Julia server unavailable")
    except Exception as e:
        raise HTTPException(500, str(e))

# Routes
@api_router.get("/")
async def root():
    """Health check."""
    return {
        "status": "online",
        "system": "TCH - Terminal de Conciencia Híbrida",
        "proxy": "FastAPI",
        "julia_port": JULIA_PORT
    }

@api_router.get("/tch/state")
async def get_tch_state():
    """Obtener estado completo del sistema TCH."""
    return await proxy_to_julia("GET", "/api/tch/state")

@api_router.get("/tch/env")
async def get_tch_env():
    """Obtener variables de entorno (estado de ánimo)."""
    return await proxy_to_julia("GET", "/api/tch/env")

@api_router.get("/tch/identity")
async def get_tch_identity():
    """Obtener identidad core."""
    return await proxy_to_julia("GET", "/api/tch/identity")

@api_router.post("/tch/input")
async def process_input(request: InputRequest):
    """Procesar input del usuario (stdin)."""
    # Log to MongoDB
    await db.chat_history.insert_one({
        "type": "input",
        "content": request.input,
        "timestamp": datetime.utcnow()
    })
    
    result = await proxy_to_julia("POST", "/api/tch/input", {"input": request.input})
    
    # Log response
    await db.chat_history.insert_one({
        "type": "output",
        "content": result.get("response", ""),
        "state": result.get("state", ""),
        "mood": result.get("mood", ""),
        "timestamp": datetime.utcnow()
    })
    
    return result

@api_router.post("/tch/tick")
async def tch_tick():
    """Avanzar un ciclo del sistema."""
    return await proxy_to_julia("POST", "/api/tch/tick")

@api_router.post("/tch/autonomous/start")
async def start_autonomous():
    """Iniciar loop autónomo de espontaneidad."""
    return await proxy_to_julia("POST", "/api/tch/autonomous/start")

@api_router.post("/tch/autonomous/stop")
async def stop_autonomous():
    """Detener loop autónomo."""
    return await proxy_to_julia("POST", "/api/tch/autonomous/stop")

@api_router.get("/tch/spontaneous")
async def get_spontaneous():
    """Obtener mensajes espontáneos (long-polling)."""
    return await proxy_to_julia("GET", "/api/tch/spontaneous")

@api_router.get("/tch/proprioception")
async def get_proprioception():
    """Obtener estado de propriocepción."""
    return await proxy_to_julia("GET", "/api/tch/proprioception")

@api_router.get("/tch/body")
async def get_body():
    """Obtener estado del esquema corporal."""
    return await proxy_to_julia("GET", "/api/tch/body")

@api_router.get("/tch/experiencias")
async def get_experiencias():
    """Obtener estadísticas del banco de experiencias."""
    return await proxy_to_julia("GET", "/api/tch/experiencias")

@api_router.get("/tch/history")
async def get_history(limit: int = 50):
    """Obtener historial de chat."""
    history = await db.chat_history.find().sort("timestamp", -1).limit(limit).to_list(limit)
    for item in history:
        item["_id"] = str(item["_id"])
    return {"history": list(reversed(history))}

@api_router.post("/tch/start")
async def start_julia():
    """Iniciar servidor Julia manualmente."""
    success = await start_julia_server()
    return {"success": success, "message": "Julia server started" if success else "Failed to start"}

@api_router.post("/tch/stop")
async def stop_julia():
    """Detener servidor Julia."""
    await stop_julia_server()
    return {"success": True, "message": "Julia server stopped"}

# WebSocket for real-time terminal
@api_router.websocket("/tch/ws")
async def websocket_terminal(websocket: WebSocket):
    """WebSocket para terminal en tiempo real."""
    await websocket.accept()
    logger.info("Terminal WebSocket connected")
    
    try:
        # Send initial state
        try:
            state = await proxy_to_julia("GET", "/api/tch/state")
            await websocket.send_json({
                "type": "state",
                "data": state
            })
        except:
            await websocket.send_json({
                "type": "error",
                "data": {"message": "Julia server starting..."}
            })
        
        while True:
            # Receive input from client
            data = await websocket.receive_text()
            msg = json.loads(data)
            
            if msg.get("type") == "input":
                input_text = msg.get("content", "")
                
                # Process through Julia
                try:
                    result = await proxy_to_julia("POST", "/api/tch/input", {"input": input_text})
                    
                    # Send response
                    await websocket.send_json({
                        "type": "response",
                        "data": result
                    })
                    
                    # Send updated env
                    env = await proxy_to_julia("GET", "/api/tch/env")
                    await websocket.send_json({
                        "type": "env",
                        "data": env
                    })
                    
                except Exception as e:
                    await websocket.send_json({
                        "type": "error",
                        "data": {"message": str(e)}
                    })
            
            elif msg.get("type") == "tick":
                try:
                    result = await proxy_to_julia("POST", "/api/tch/tick")
                    await websocket.send_json({
                        "type": "tick",
                        "data": result
                    })
                except Exception as e:
                    await websocket.send_json({
                        "type": "error",
                        "data": {"message": str(e)}
                    })
            
            elif msg.get("type") == "env":
                try:
                    env = await proxy_to_julia("GET", "/api/tch/env")
                    await websocket.send_json({
                        "type": "env",
                        "data": env
                    })
                except Exception as e:
                    pass
                    
    except WebSocketDisconnect:
        logger.info("Terminal WebSocket disconnected")
    except Exception as e:
        logger.error(f"WebSocket error: {e}")

# Include router
app.include_router(api_router)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_credentials=True,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
async def startup():
    """Iniciar Julia server al arrancar."""
    logger.info("="*60)
    logger.info("  TCH - Terminal de Conciencia Híbrida")
    logger.info("  Ψ_TCH = { N1: Autoridad | G: Adaptabilidad }")
    logger.info("="*60)
    
    # Start Julia in background
    asyncio.create_task(start_julia_server())

@app.on_event("shutdown")
async def shutdown():
    """Cleanup."""
    await stop_julia_server()
    client.close()
