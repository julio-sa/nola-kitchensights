from fastapi import APIRouter, Depends, Query
from app.core.database import get_db_session
from app.repositories.sales_repository import SalesRepository
from app.services.widget_service import WidgetService
from app.models.widgets import (
    TopProductsResponse,
    DeliveryHeatmapResponse,
    AtRiskCustomersResponse,
    ChannelPerformanceResponse
)

router = APIRouter(prefix="/widgets", tags=["Widgets"])

@router.get("/top-products", response_model=TopProductsResponse)
async def get_top_products(
    store_id: int = Query(..., description="ID da loja"),
    channel: str = Query(..., description="Canal de venda (ex: iFood, Rappi, Presencial)"),
    day_of_week: int = Query(..., ge=1, le=7, description="Dia da semana (1=segunda, 7=domingo)"),
    hour_start: int = Query(..., ge=0, le=23, description="Hora inicial (0-23)"),
    hour_end: int = Query(..., ge=0, le=23, description="Hora final (0-23)"),
    db_session = Depends(get_db_session)
):
    """
    Retorna os produtos mais vendidos em um canal específico, dia da semana e faixa horária.
    Inclui comparação com a mesma janela na semana anterior para identificar tendências.
    Exemplo de uso: "Quais produtos vendem mais no iFood às quintas à noite?"
    """
    repository = SalesRepository(db_session)
    service = WidgetService(repository)
    return await service.get_top_products_insight(
        store_id, channel, day_of_week, hour_start, hour_end
    )

@router.get("/delivery-heatmap", response_model=DeliveryHeatmapResponse)
async def get_delivery_heatmap(
    store_id: int = Query(..., description="ID da loja"),
    db_session = Depends(get_db_session)
):
    """
    Mostra regiões com pior desempenho de entrega (tempo médio e p90).
    Destaca variação semanal para identificar degradação de serviço.
    Responde: "Meu tempo de entrega piorou. Em quais regiões?"
    """
    repository = SalesRepository(db_session)
    service = WidgetService(repository)
    return await service.get_delivery_heatmap_insight(store_id)

@router.get("/at-risk-customers", response_model=AtRiskCustomersResponse)
async def get_at_risk_customers(
    store_id: int = Query(..., description="ID da loja"),
    db_session = Depends(get_db_session)
):
    """
    Lista clientes com histórico de fidelidade (≥3 compras) que não voltaram nos últimos 30 dias.
    Permite ações de retenção (ex: cupom de retorno).
    Responde: "Quais clientes compraram 3+ vezes mas não voltam há 30 dias?"
    """
    repository = SalesRepository(db_session)
    service = WidgetService(repository)
    return await service.get_at_risk_customers_insight(store_id)

@router.get("/channel-performance", response_model=ChannelPerformanceResponse)
async def get_channel_performance(
    store_id: int = Query(..., description="ID da loja"),
    period_days: int = Query(30, ge=1, le=180, description="Período em dias para análise"),
    db_session = Depends(get_db_session)
):
    """
    Compara performance entre canais de venda (faturamento, ticket médio, volume).
    Inclui distribuição horária para identificar picos de demanda por canal.
    Responde: "Qual plataforma vende mais? Em que horário?"
    """
    repository = SalesRepository(db_session)
    service = WidgetService(repository)
    return await service.get_channel_performance_insight(store_id, period_days)