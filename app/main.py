from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.v1.api_v1 import api_router

app = FastAPI(
    title="Nola Analytics API",
    description="Plataforma de analytics customizável para donos de restaurantes",
    version="1.0.0"
)

# ⚠️ CORS deve ser o PRIMEIRO middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Permite todas as origens (só para desenvolvimento)
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Só depois adiciona as rotas
app.include_router(api_router, prefix="/api/v1")