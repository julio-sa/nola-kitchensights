from fastapi import APIRouter
from app.api.v1.routes import widgets, auth

api_router = APIRouter()
api_router.include_router(widgets.router)
api_router.include_router(auth.router)