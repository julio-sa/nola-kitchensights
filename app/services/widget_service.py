from __future__ import annotations

import json
from datetime import date, timedelta
from typing import Optional
from app.models.widgets import (
    AtRiskCustomersResponse,
    ChannelPerformanceResponse,
    ChannelPerformanceItem,
    DeliveryHeatmapResponse,
    DeliveryRegionInsight,
    RevenueDailyPoint,
    RevenueOverviewResponse,
    RevenueTopChannel,
    StoreComparisonResponse,
    StoreComparisonStore,
    TopProductItem,
    TopProductsResponse,
)
from app.repositories.sales_repository import SalesRepository


class WidgetService:
    """Camada de orquestração entre API e banco de dados."""

    def __init__(self, repository: SalesRepository):
        self.repo = repository

    async def get_top_products_insight(
        self,
        store_id: int,
        channel: str,
        day_of_week: int,
        hour_start: int,
        hour_end: int,
    ) -> TopProductsResponse:
        raw_data = await self.repo.get_top_products_by_channel_and_time(
            store_id, channel, day_of_week, hour_start, hour_end
        )
        products = [
            TopProductItem(
                product_name=row["product_name"],
                total_quantity_sold=row["total_quantity"],
                total_revenue=float(row["total_revenue"]),
                percentage_of_total=float(row.get("pct_of_total") or 0),
                week_over_week_change_pct=
                    float(row["wow_change_pct"]) if row.get("wow_change_pct") is not None else None,
            )
            for row in raw_data
        ]
        return TopProductsResponse(
            store_id=store_id,
            channel=channel,
            day_of_week=day_of_week,
            hour_start=hour_start,
            hour_end=hour_end,
            products=products,
        )

    async def get_delivery_heatmap_insight(self, store_id: int) -> DeliveryHeatmapResponse:
        raw_data = await self.repo.get_delivery_heatmap_by_store(store_id)
        regions = [
            DeliveryRegionInsight(
                neighborhood=row["neighborhood"],
                city=row["city"],
                delivery_count=row["delivery_count"],
                avg_delivery_minutes=float(row["avg_delivery_minutes"]),
                p90_delivery_minutes=float(row["p90_delivery_minutes"]),
                week_over_week_change_pct=
                    float(row["wow_change_pct"]) if row.get("wow_change_pct") is not None else None,
            )
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
                "days_since_last_order": row["days_since_last_order"],
            }
            for row in raw_data
        ]
        return AtRiskCustomersResponse(store_id=store_id, customers=customers)

    async def get_channel_performance_insight(
        self,
        store_id: int,
        period_days: int,
    ) -> ChannelPerformanceResponse:
        raw_data = await self.repo.get_channel_performance(store_id, period_days)
        channels = []
        for row in raw_data:
            hourly = row.get("hourly_distribution")
            if isinstance(hourly, str):
                # SQL retorna string JSON; converte para dict simples
                hourly = json.loads(hourly)
            channels.append(
                ChannelPerformanceItem(
                    channel_name=row["channel_name"],
                    total_sales=float(row["total_sales"]),
                    total_orders=row["total_orders"],
                    average_ticket=float(row["average_ticket"]),
                    hourly_distribution={k: int(v) for k, v in (hourly or {}).items()},
                )
            )
        return ChannelPerformanceResponse(
            store_id=store_id,
            period_days=period_days,
            channels=channels,
        )

    async def get_revenue_overview(
        self,
        store_id: int,
        start_date: Optional[date],
        end_date: Optional[date],
    ) -> RevenueOverviewResponse:
        today = date.today()
        if start_date is None or end_date is None:
            # Padrão: mês corrente
            start_date = date(today.year, today.month, 1) if start_date is None else start_date
            if end_date is None:
                next_month = (start_date.replace(day=1) + timedelta(days=32)).replace(day=1)
                end_date = next_month - timedelta(days=1)
            if end_date < start_date:
                end_date = today
        summary = await self.repo.get_revenue_overview(store_id, start_date, end_date)
        top_channels = [
            RevenueTopChannel(
                channel=row["channel"],
                total_sales=float(row["total_sales"]),
                share_pct=float(row["share_pct"]),
            )
            for row in summary.get("top_channels", [])
        ]
        daily_breakdown = [
            RevenueDailyPoint(
                date=row["sale_date"],
                total_sales=float(row["total_sales"]),
                total_orders=row["total_orders"],
            )
            for row in summary.get("daily_breakdown", [])
        ]
        return RevenueOverviewResponse(
            store_id=store_id,
            start_date=start_date,
            end_date=end_date,
            total_sales=float(summary["total_sales"]),
            total_orders=summary["total_orders"],
            average_ticket=float(summary["average_ticket"]),
            sales_change_pct=float(summary["sales_change_pct"]),
            orders_change_pct=float(summary["orders_change_pct"]),
            top_channels=top_channels,
            daily_breakdown=daily_breakdown,
        )

    async def get_store_comparison(
        self,
        store_a_id: int,
        store_b_id: int,
        start_date: date,
        end_date: date,
    ) -> StoreComparisonResponse:
        comparison = await self.repo.get_store_comparison(
            store_a_id, store_b_id, start_date, end_date
        )
        stores = [
            StoreComparisonStore(
                store_id=row["store_id"],
                store_name=row["store_name"],
                total_sales=float(row["total_sales"]),
                total_orders=row["total_orders"],
                average_ticket=float(row["average_ticket"]),
                sales_change_pct=float(row["sales_change_pct"]),
                top_channel=row.get("top_channel"),
                top_channel_share_pct=
                    float(row["top_channel_share_pct"]) if row.get("top_channel_share_pct") is not None else None,
            )
            for row in comparison
        ]
        return StoreComparisonResponse(
            period_start=start_date,
            period_end=end_date,
            stores=stores,
        )
