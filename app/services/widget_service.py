# app/services/widget_service.py
from __future__ import annotations

from datetime import date
from typing import Optional

from app.repositories.sales_repository import SalesRepository


class WidgetService:
    def __init__(self, repo: SalesRepository):
        self.repo = repo

    async def list_channels_for_store(self, store_id: int):
        return await self.repo.list_channels_for_store(store_id)

    async def get_top_products_insight(
        self,
        store_id: int,
        channel: str,
        day_of_week: int,
        hour_start: int,
        hour_end: int,
    ):
        rows = await self.repo.get_top_products_by_channel_and_time(
            store_id=store_id,
            channel=channel,
            day_of_week=day_of_week,
            hour_start=hour_start,
            hour_end=hour_end,
            limit=10,
        )
        return {
            "store_id": store_id,
            "channel": channel,
            "day_of_week": day_of_week,
            "hour_start": hour_start,
            "hour_end": hour_end,
            "products": rows,
        }

    async def get_top_products_flexible(
            self,
            store_id: int,
            channel_name: Optional[str],
            start_date: date,
            end_date: date,
            day_of_week: Optional[int],
            hour_start: Optional[int],
            hour_end: Optional[int],
            limit: int = 10,
    ):
        # 1) tenta exatamente o que o Flutter pediu
        rows = await self.repo.get_top_products_flexible(
            store_id=store_id,
            channel_name=channel_name,
            start_date=start_date,
            end_date=end_date,
            day_of_week=day_of_week,
            hour_start=hour_start,
            hour_end=hour_end,
            limit=limit,
        )
        if rows:
            return rows

        # 2) se veio vazio e tinha canal, tenta sem canal
        if channel_name is not None:
            rows = await self.repo.get_top_products_flexible(
                store_id=store_id,
                channel_name=None,  # 👈 tira o canal
                start_date=start_date,
                end_date=end_date,
                day_of_week=day_of_week,
                hour_start=hour_start,
                hour_end=hour_end,
                limit=limit,
            )
            if rows:
                return rows

        # 3) se ainda veio vazio e tinha dia/hora, tenta só o período
        if day_of_week is not None or (hour_start is not None and hour_end is not None):
            rows = await self.repo.get_top_products_flexible(
                store_id=store_id,
                channel_name=None,
                start_date=start_date,
                end_date=end_date,
                day_of_week=None,
                hour_start=None,
                hour_end=None,
                limit=limit,
            )
            return rows

        # 4) se nada deu, devolve vazio mesmo
        return rows

    async def get_delivery_heatmap_insight(
        self,
        store_id: int,
        start_date: Optional[date],
        end_date: Optional[date],
    ):
        rows = await self.repo.get_delivery_heatmap_by_store(
            store_id=store_id,
            start_date=start_date,
            end_date=end_date,
        )
        return {
            "store_id": store_id,
            "period_start": start_date,
            "period_end": end_date,
            "regions": rows,
        }

    async def get_at_risk_customers_insight(self, store_id: int):
        rows = await self.repo.get_at_risk_customers(store_id)
        return {
            "store_id": store_id,
            "customers": rows,
        }

    async def get_channel_performance_insight(self, store_id: int, period_days: int = 30):
        # se quiser depois a gente liga nesse teu SQL de channel_performance
        return await self.repo.get_channel_performance(store_id, period_days)

    async def get_revenue_overview(
        self,
        store_id: int,
        start_date: Optional[date],
        end_date: Optional[date],
    ):
        # se não vier período, faz igual teu provider fazia: pega mês atual
        if end_date is None:
            end_date = date.today()
        if start_date is None:
            start_date = end_date.replace(day=1)

        data = await self.repo.get_revenue_overview(
            store_id=store_id,
            start_date=start_date,
            end_date=end_date,
        )
        return {
            "store_id": store_id,
            "start_date": start_date,
            "end_date": end_date,
            **data,
        }

    async def get_store_comparison(
        self,
        store_a_id: int,
        store_b_id: int,
        start_date: date,
        end_date: date,
    ):
        rows = await self.repo.get_store_comparison(
            store_a_id=store_a_id,
            store_b_id=store_b_id,
            start_date=start_date,
            end_date=end_date,
        )
        return {
            "period_start": start_date,
            "period_end": end_date,
            "stores": rows,
        }

    async def list_available_stores(self):
        return await self.repo.list_available_stores()
