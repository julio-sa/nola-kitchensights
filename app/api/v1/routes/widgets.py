# app/api/v1/routes/widgets.py
from datetime import date
from typing import Optional, AsyncGenerator
import os

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    create_async_engine,
    async_sessionmaker,
)

from app.repositories.sales_repository import SalesRepository
from app.services.widget_service import WidgetService

router = APIRouter(tags=["widgets"])

# --------------------------------------------------------
# DB assíncrono local ao módulo
# --------------------------------------------------------
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
    expire_on_commit=False,
)


async def get_session() -> AsyncGenerator[AsyncSession, None]:
    async with SessionLocal() as session:
        yield session


def get_widget_service(db: AsyncSession = Depends(get_session)) -> WidgetService:
    repo = SalesRepository(db)
    return WidgetService(repo)


# --------------------------------------------------------
# ENDPOINTS
# --------------------------------------------------------

@router.get("/store-channels")
async def get_store_channels(
    store_id: int,
    service: WidgetService = Depends(get_widget_service),
):
    return await service.list_channels_for_store(store_id)


@router.get("/top-products")
async def get_top_products(
    store_id: int,
    channel: str,
    day_of_week: int = Query(..., ge=1, le=7),
    hour_start: int = Query(0, ge=0, le=23),
    hour_end: int = Query(23, ge=0, le=23),
    service: WidgetService = Depends(get_widget_service),
):
    return await service.get_top_products_insight(
        store_id,
        channel,
        day_of_week,
        hour_start,
        hour_end,
    )

@router.get("/top-products-flex")
async def get_top_products_flex(
    store_id: int = Query(..., description="ID da loja"),
    start_date: date = Query(..., description="início do período"),
    end_date: date = Query(..., description="fim do período"),
    channel: Optional[str] = Query(None, description="nome exato do canal, ex: iFood, Rappi, App próprio"),
    day_of_week: Optional[int] = Query(
        None,
        ge=1,
        le=7,
        description="1=segunda ... 7=domingo (opcional)",
    ),
    hour_start: Optional[int] = Query(None, ge=0, le=23),
    hour_end: Optional[int] = Query(None, ge=0, le=23),
    limit: int = Query(10, ge=1, le=50),
    service: WidgetService = Depends(get_widget_service),
):
    """
    Versão flexível para o card de Top Produtos (com popup de filtros).
    Se você não passar canal/dia/horário, ele considera só o período.
    """
    rows = await service.get_top_products_flexible(
        store_id=store_id,
        channel_name=channel,
        start_date=start_date,
        end_date=end_date,
        day_of_week=day_of_week,
        hour_start=hour_start,
        hour_end=hour_end,
        limit=limit,
    )
    return {
        "store_id": store_id,
        "start_date": start_date,
        "end_date": end_date,
        "channel": channel,
        "day_of_week": day_of_week,
        "hour_start": hour_start,
        "hour_end": hour_end,
        "products": rows,
    }

@router.get("/delivery-heatmap")
async def get_delivery_heatmap(
    store_id: int = Query(...),
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    service: WidgetService = Depends(get_widget_service),
):
    return await service.get_delivery_heatmap_insight(
        store_id=store_id,
        start_date=start_date,
        end_date=end_date,
    )


@router.get("/at-risk-customers")
async def get_at_risk_customers(
    store_id: int,
    service: WidgetService = Depends(get_widget_service),
):
    return await service.get_at_risk_customers_insight(store_id)


@router.get("/channel-performance")
async def get_channel_performance(
    store_id: int,
    period_days: int = Query(30, ge=1, le=90),
    service: WidgetService = Depends(get_widget_service),
):
    return await service.get_channel_performance_insight(store_id, period_days)


@router.get("/revenue-overview")
async def get_revenue_overview(
    store_id: int,
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    service: WidgetService = Depends(get_widget_service),
):
    return await service.get_revenue_overview(store_id, start_date, end_date)


@router.get("/store-comparison")
async def get_store_comparison(
    store_a_id: int = Query(..., alias="store_a_id"),
    store_b_id: int = Query(..., alias="store_b_id"),
    start_date: date = Query(...),
    end_date: date = Query(...),
    service: WidgetService = Depends(get_widget_service),
):
    return await service.get_store_comparison(
        store_a_id,
        store_b_id,
        start_date,
        end_date,
    )


@router.get("/available-stores")
async def get_available_stores(
    service: WidgetService = Depends(get_widget_service),
):
    return await service.list_available_stores()


# opcional: simular que a Maria tem 3 lojas
@router.get("/maria/stores")
async def get_maria_stores(
    service: WidgetService = Depends(get_widget_service),
):
    stores = await service.list_available_stores()
    return {
        "owner": "Maria",
        "stores": stores[:3],
        "note": "Simulação: dataset não traz vínculo usuário→loja; usamos as 3 lojas com mais entregas.",
    }
