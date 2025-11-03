# app/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.routes import widgets as widgets_router

app = FastAPI(title="Nola KitchenSights API")

# CORS bem aberto pra dev
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # depois você pode trocar por ["http://localhost:8386"]
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# registra as rotas
app.include_router(
    widgets_router.router,
    prefix="/api/v1/widgets",
    tags=["widgets"],
)

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/")
async def root():
    return {"status": "ok", "app": "nola-kitchensights"}
