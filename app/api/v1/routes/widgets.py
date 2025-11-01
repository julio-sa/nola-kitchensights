from datetime import date

from fastapi import APIRouter, Depends, Query

from app.core.database import get_db_session
from app.repositories.sales_repository import SalesRepository
from app.services.widget_service import WidgetService
from app.models.widgets import (
    AtRiskCustomersResponse,
    ChannelPerformanceResponse,
    DeliveryHeatmapResponse,
    RevenueOverviewResponse,
    StoreComparisonResponse,
    TopProductsResponse,
)

router = APIRouter(prefix="/widgets", tags=["Widgets"])


@router.get("/top-products", response_model=TopProductsResponse)
async def get_top_products(
    store_id: int = Query(..., description="ID da loja"),
    channel: str = Query(..., description="Canal de venda (ex: iFood, Rappi, Presencial)"),
    day_of_week: int = Query(..., ge=1, le=7, description="Dia da semana (1=segunda, 7=domingo)"),
    hour_start: int = Query(..., ge=0, le=23, description="Hora inicial (0-23)"),
    hour_end: int = Query(..., ge=0, le=23, description="Hora final (0-23)"),
    db_session=Depends(get_db_session),
):
    """Produtos mais vendidos para uma janela específica de canal/dia/horário."""
    repository = SalesRepository(db_session)
    service = WidgetService(repository)
    return await service.get_top_products_insight(
        store_id, channel, day_of_week, hour_start, hour_end
    )


@router.get("/delivery-heatmap", response_model=DeliveryHeatmapResponse)
async def get_delivery_heatmap(
    store_id: int = Query(..., description="ID da loja"),
    db_session=Depends(get_db_session),
):
    """Regiões com pior desempenho de entrega (tempo médio e p90)."""
    repository = SalesRepository(db_session)
    service = WidgetService(repository)
    return await service.get_delivery_heatmap_insight(store_id)


@router.get("/at-risk-customers", response_model=AtRiskCustomersResponse)
async def get_at_risk_customers(
    store_id: int = Query(..., description="ID da loja"),
    db_session=Depends(get_db_session),
):
    """Clientes fiéis que não compram há 30 dias."""
    repository = SalesRepository(db_session)
    service = WidgetService(repository)
    return await service.get_at_risk_customers_insight(store_id)


@router.get("/channel-performance", response_model=ChannelPerformanceResponse)
async def get_channel_performance(
    store_id: int = Query(..., description="ID da loja"),
    period_days: int = Query(30, ge=1, le=180, description="Período em dias para análise"),
    db_session=Depends(get_db_session),
):
    """Comparação de performance entre canais de venda."""
    repository = SalesRepository(db_session)
    service = WidgetService(repository)
    return await service.get_channel_performance_insight(store_id, period_days)


@router.get("/revenue-overview", response_model=RevenueOverviewResponse)
async def get_revenue_overview(
    store_id: int = Query(..., description="ID da loja"),
    start_date: date | None = Query(None, description="Data inicial (YYYY-MM-DD)"),
    end_date: date | None = Query(None, description="Data final (YYYY-MM-DD)"),
    db_session=Depends(get_db_session),
):
    """Resumo executivo do período selecionado com variação versus período anterior."""
    repository = SalesRepository(db_session)
    service = WidgetService(repository)
    return await service.get_revenue_overview(store_id, start_date, end_date)


@router.get("/store-comparison", response_model=StoreComparisonResponse)
async def get_store_comparison(
    store_a_id: int = Query(..., description="Loja principal"),
    store_b_id: int = Query(..., description="Loja de comparação"),
    start_date: date = Query(..., description="Data inicial (YYYY-MM-DD)"),
    end_date: date = Query(..., description="Data final (YYYY-MM-DD)"),
    db_session=Depends(get_db_session),
):
    """Compara o desempenho de duas lojas lado a lado."""
    repository = SalesRepository(db_session)
    service = WidgetService(repository)
    return await service.get_store_comparison(store_a_id, store_b_id, start_date, end_date)
