from app.repositories.sales_repository import SalesRepository
from app.models.widgets import (
    TopProductsResponse,
    DeliveryHeatmapResponse,
    AtRiskCustomersResponse,
    ChannelPerformanceResponse
)
from typing import List

class WidgetService:
    """
    Camada de lógica de negócio. Orquestra repositórios e transforma dados brutos
    em respostas estruturadas para os endpoints.
    """

    def __init__(self, repository: SalesRepository):
        self.repo = repository

    async def get_top_products_insight(
        self,
        store_id: int,
        channel: str,
        day_of_week: int,
        hour_start: int,
        hour_end: int
    ) -> TopProductsResponse:
        raw_data = await self.repo.get_top_products_by_channel_and_time(
            store_id, channel, day_of_week, hour_start, hour_end
        )
        products = [
            {
                "product_name": row["product_name"],
                "total_quantity_sold": row["total_quantity"],
                "total_revenue": float(row["total_revenue"]),
                "percentage_of_total": float(row["pct_of_total"] or 0),
                "week_over_week_change_pct": float(row["wow_change_pct"]) if row["wow_change_pct"] is not None else None
            }
            for row in raw_data
        ]
        return TopProductsResponse(
            store_id=store_id,
            channel=channel,
            day_of_week=day_of_week,
            hour_start=hour_start,
            hour_end=hour_end,
            products=products
        )

    async def get_delivery_heatmap_insight(self, store_id: int) -> DeliveryHeatmapResponse:
        raw_data = await self.repo.get_delivery_heatmap_by_store(store_id)
        regions = [
            {
                "neighborhood": row["neighborhood"],
                "city": row["city"],
                "delivery_count": row["delivery_count"],
                "avg_delivery_minutes": float(row["avg_delivery_minutes"]),
                "p90_delivery_minutes": float(row["p90_delivery_minutes"]),
                "week_over_week_change_pct": float(row["wow_change_pct"]) if row["wow_change_pct"] is not None else None
            }
            for row in raw_data
        ]
        return DeliveryHeatmapResponse(store_id=store_id, regions=regions)

    async def get_at_risk_customers_insight(self, store_id: int) -> AtRiskCustomersResponse:
        raw_data = await self.repo.get_at_risk_customers(store_id)
        customers = [
            {
                "customer_name": row["customer_name"],
                "customer_id": row["customer_id"],
                "total_orders": row["total_orders"],
                "last_order_date": row["last_order_date"],
                "days_since_last_order": row["days_since_last_order"]
            }
            for row in raw_data
        ]
        return AtRiskCustomersResponse(store_id=store_id, customers=customers)

    async def get_channel_performance_insight(self, store_id: int, period_days: int) -> ChannelPerformanceResponse:
        raw_data = await self.repo.get_channel_performance(store_id, period_days)
        channels = []
        for row in raw_data:
            # Converte JSON string para dict (ajustar conforme retorno real)
            hourly = row["hourly_distribution"]
            channels.append({
                "channel_name": row["channel_name"],
                "total_sales": float(row["total_sales"]),
                "total_orders": row["total_orders"],
                "average_ticket": float(row["average_ticket"]),
                "hourly_distribution": hourly if isinstance(hourly, dict) else {}
            })
        return ChannelPerformanceResponse(
            store_id=store_id,
            period_days=period_days,
            channels=channels
        )