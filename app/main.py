from fastapi import FastAPI
from app.api.v1.api_v1 import api_router
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(
    title="Nola Analytics API",
    description="Plataforma de analytics customizável para donos de restaurantes",
    version="1.0.0"
)

# Permitir CORS para Flutter Web
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*", "http://localhost",
                   "http://127.0.0.1, "
                   "http://localhost:*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix="/api/v1")