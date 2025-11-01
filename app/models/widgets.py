from __future__ import annotations

from datetime import date
from typing import Dict, List, Optional

from pydantic import BaseModel, ConfigDict, Field


class ItemAccessMixin(BaseModel):
    """Permite acesso estilo dicionário usado nos testes/unit tests."""

    model_config = ConfigDict(from_attributes=True)

    def __getitem__(self, item: str):  # pragma: no cover - acesso simples
        return getattr(self, item)


class TopProductItem(ItemAccessMixin):
    product_name: str
    total_quantity_sold: int
    total_revenue: float
    percentage_of_total: float
    week_over_week_change_pct: Optional[float]


class TopProductsResponse(BaseModel):
    store_id: int
    channel: str
    day_of_week: int
    hour_start: int
    hour_end: int
    products: List[TopProductItem]


class DeliveryRegionInsight(ItemAccessMixin):
    neighborhood: str
    city: str
    delivery_count: int
    avg_delivery_minutes: float
    p90_delivery_minutes: float
    week_over_week_change_pct: Optional[float]


class DeliveryHeatmapResponse(BaseModel):
    store_id: int
    regions: List[DeliveryRegionInsight]


class AtRiskCustomer(ItemAccessMixin):
    customer_name: Optional[str] = "Cliente Anônimo"
    customer_id: int
    total_orders: int
    last_order_date: date
    days_since_last_order: int


class AtRiskCustomersResponse(BaseModel):
    store_id: int
    customers: List[AtRiskCustomer]


class ChannelPerformanceItem(ItemAccessMixin):
    channel_name: str
    total_sales: float
    total_orders: int
    average_ticket: float
    hourly_distribution: Dict[str, int]


class ChannelPerformanceResponse(BaseModel):
    store_id: int
    period_days: int
    channels: List[ChannelPerformanceItem]


class RevenueTopChannel(ItemAccessMixin):
    channel: str
    total_sales: float
    share_pct: float


class RevenueDailyPoint(ItemAccessMixin):
    date: date
    total_sales: float
    total_orders: int


class RevenueOverviewResponse(BaseModel):
    store_id: int
    start_date: date
    end_date: date
    total_sales: float
    total_orders: int
    average_ticket: float
    sales_change_pct: float
    orders_change_pct: float
    top_channels: List[RevenueTopChannel] = Field(default_factory=list)
    daily_breakdown: List[RevenueDailyPoint] = Field(default_factory=list)


class StoreComparisonStore(ItemAccessMixin):
    store_id: int
    store_name: str
    total_sales: float
    total_orders: int
    average_ticket: float
    sales_change_pct: float
    top_channel: Optional[str]
    top_channel_share_pct: Optional[float]


class StoreComparisonResponse(BaseModel):
    period_start: date
    period_end: date
    stores: List[StoreComparisonStore]
