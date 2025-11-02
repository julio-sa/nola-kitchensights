# app/main.py
import os
from datetime import date
from typing import Optional

from fastapi import FastAPI, Depends, Query
from fastapi.middleware.cors import CORSMiddleware

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    create_async_engine,
    async_sessionmaker,
)

# ⚠️ IMPORTA O QUE JÁ EXISTE NO SEU PROJETO
from .repositories.sales_repository import SalesRepository
from .services.widget_service import WidgetService

# ---------------------------------------------------------------------
# 1. CONFIGURAÇÃO DO BANCO (AQUI MESMO, SEM db.py)
# ---------------------------------------------------------------------
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+asyncpg://challenge:challenge@localhost:5432/challenge_db",
)

engine = create_async_engine(
    DATABASE_URL,
    echo=False,
    future=True,
)

SessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


async def get_session() -> AsyncSession:
    # FastAPI vai cuidar do ciclo async
    async with SessionLocal() as session:
        yield session


# ---------------------------------------------------------------------
# 2. APP FASTAPI
# ---------------------------------------------------------------------
app = FastAPI(
    title="Nola KitchenSights API",
    version="1.0.0",
)

# CORS - põe os hosts do Flutter Web / VSCode Preview
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://localhost:4200",
        "http://localhost:5173",
        "http://localhost:59518",
        "http://localhost:30409",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:59518",
        "http://127.0.0.1:30409",
        "*",  # se quiser deixar bem aberto
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# helper pra não repetir criação do service
def _make_widget_service(db: AsyncSession) -> WidgetService:
    repo = SalesRepository(db)
    return WidgetService(repo)


# ---------------------------------------------------------------------
# 3. ROTAS DE WIDGETS (TUDO AQUI, SEM IMPORTAR OUTRO ROUTER)
# ---------------------------------------------------------------------

@app.get("/")
async def root():
    return {"ok": True, "msg": "Nola KitchenSights API up"}


@app.get("/api/v1/widgets/top-products")
async def top_products(
    store_id: int,
    channel: str,
    day_of_week: int = Query(..., ge=1, le=7),
    hour_start: int = Query(0, ge=0, le=23),
    hour_end: int = Query(23, ge=0, le=23),
    db: AsyncSession = Depends(get_session),
):
    service = _make_widget_service(db)
    return await service.get_top_products_insight(
        store_id,
        channel,
        day_of_week,
        hour_start,
        hour_end,
    )


@app.get("/api/v1/widgets/delivery-heatmap")
async def delivery_heatmap(
    store_id: int,
    db: AsyncSession = Depends(get_session),
):
    service = _make_widget_service(db)
    return await service.get_delivery_heatmap_insight(store_id)


@app.get("/api/v1/widgets/at-risk-customers")
async def at_risk_customers(
    store_id: int,
    db: AsyncSession = Depends(get_session),
):
    service = _make_widget_service(db)
    return await service.get_at_risk_customers_insight(store_id)


@app.get("/api/v1/widgets/channel-performance")
async def channel_performance(
    store_id: int,
    period_days: int = Query(30, ge=1, le=90),
    db: AsyncSession = Depends(get_session),
):
    service = _make_widget_service(db)
    return await service.get_channel_performance_insight(store_id, period_days)


@app.get("/api/v1/widgets/revenue-overview")
async def revenue_overview(
    store_id: int,
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    db: AsyncSession = Depends(get_session),
):
    service = _make_widget_service(db)
    return await service.get_revenue_overview(store_id, start_date, end_date)


@app.get("/api/v1/widgets/store-comparison")
async def store_comparison(
    store_a_id: int = Query(..., alias="store_a_id"),
    store_b_id: int = Query(..., alias="store_b_id"),
    start_date: date = Query(...),
    end_date: date = Query(...),
    db: AsyncSession = Depends(get_session),
):
    service = _make_widget_service(db)
    return await service.get_store_comparison(
        store_a_id,
        store_b_id,
        start_date,
        end_date,
    )


# ---------------------------------------------------------------------
# 4. ENTRYPOINT
# ---------------------------------------------------------------------
# roda com: uvicorn app.main:app --reload
if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
    )
