from pydantic import BaseModel
from typing import List, Optional
from datetime import date

# === MODELOS DE RESPOSTA DOS WIDGETS ===

class TopProductItem(BaseModel):
    product_name: str
    total_quantity_sold: int
    total_revenue: float
    percentage_of_total: float
    week_over_week_change_pct: Optional[float]  # variação vs semana anterior

class TopProductsResponse(BaseModel):
    store_id: int
    channel: str
    day_of_week: int  # 1=segunda, ..., 7=domingo
    hour_start: int
    hour_end: int
    products: List[TopProductItem]

# ---

class DeliveryRegionInsight(BaseModel):
    neighborhood: str
    city: str
    delivery_count: int
    avg_delivery_minutes: float
    p90_delivery_minutes: float
    week_over_week_change_pct: Optional[float]

class DeliveryHeatmapResponse(BaseModel):
    store_id: int
    regions: List[DeliveryRegionInsight]

# ---

class AtRiskCustomer(BaseModel):
    customer_name: str
    customer_id: int
    total_orders: int
    last_order_date: date
    days_since_last_order: int

class AtRiskCustomersResponse(BaseModel):
    store_id: int
    customers: List[AtRiskCustomer]

# ---

class ChannelPerformanceItem(BaseModel):
    channel_name: str
    total_sales: float
    total_orders: int
    average_ticket: float
    hourly_distribution: dict  # ex: { "19": 120, "20": 150, ... }

class ChannelPerformanceResponse(BaseModel):
    store_id: int
    period_days: int
    channels: List[ChannelPerformanceItem]