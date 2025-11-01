from fastapi import APIRouter

from app.api.v1.routes import auth, reports, widgets

api_router = APIRouter()
api_router.include_router(widgets.router)
api_router.include_router(reports.router)
api_router.include_router(auth.router)
