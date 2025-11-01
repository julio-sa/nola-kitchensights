from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from typing import List, Dict, Any

class SalesRepository:
    """
    Camada de acesso a dados. Contém queries SQL otimizadas diretamente.
    Foco em performance e clareza — cada método resolve uma pergunta específica.
    """

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_top_products_by_channel_and_time(
        self,
        store_id: int,
        channel_name: str,
        day_of_week: int,  # 1-7 (seg-dom)
        hour_start: int,
        hour_end: int
    ) -> List[Dict[str, Any]]:
        """
        Retorna os produtos mais vendidos em um canal, dia da semana e faixa horária.
        Inclui comparação com a mesma janela na semana anterior.
        """
        query = text("""
        WITH current_period AS (
            SELECT 
                p.name AS product_name,
                SUM(ps.quantity) AS total_quantity,
                SUM(ps.total_price) AS total_revenue
            FROM sales s
            JOIN channels ch ON ch.id = s.channel_id
            JOIN product_sales ps ON ps.sale_id = s.id
            JOIN products p ON p.id = ps.product_id
            WHERE s.store_id = :store_id
              AND ch.name = :channel_name
              AND s.sale_status_desc = 'COMPLETED'
              AND EXTRACT(DOW FROM s.created_at) = :dow  -- 0=domingo, 1=seg... (PostgreSQL)
              AND EXTRACT(HOUR FROM s.created_at) BETWEEN :hour_start AND :hour_end
              AND s.created_at >= NOW() - INTERVAL '7 days'
            GROUP BY p.name
        ),
        previous_period AS (
            SELECT 
                p.name AS product_name,
                SUM(ps.quantity) AS total_quantity
            FROM sales s
            JOIN channels ch ON ch.id = s.channel_id
            JOIN product_sales ps ON ps.sale_id = s.id
            JOIN products p ON p.id = ps.product_id
            WHERE s.store_id = :store_id
              AND ch.name = :channel_name
              AND s.sale_status_desc = 'COMPLETED'
              AND EXTRACT(DOW FROM s.created_at) = :dow
              AND EXTRACT(HOUR FROM s.created_at) BETWEEN :hour_start AND :hour_end
              AND s.created_at BETWEEN NOW() - INTERVAL '14 days' AND NOW() - INTERVAL '7 days'
            GROUP BY p.name
        )
        SELECT 
            cp.product_name,
            cp.total_quantity,
            cp.total_revenue,
            ROUND(
                (cp.total_revenue / NULLIF((SELECT SUM(total_revenue) FROM current_period), 0) * 100)::NUMERIC, 2
            ) AS pct_of_total,
            ROUND(
                ((cp.total_quantity - COALESCE(pp.total_quantity, 0))::DECIMAL 
                 / NULLIF(pp.total_quantity, 0) * 100)::NUMERIC, 2
            ) AS wow_change_pct
        FROM current_period cp
        LEFT JOIN previous_period pp ON pp.product_name = cp.product_name
        ORDER BY cp.total_revenue DESC;
        """)

        pg_dow = (day_of_week % 7)  # 1=seg → 1, 7=dom → 0

        result = await self.db.execute(query, {
            "store_id": store_id,
            "channel_name": channel_name,
            "dow": pg_dow,  # ajuste: FastAPI envia 1=seg, PG usa 0=dom → seg=1
            "hour_start": hour_start,
            "hour_end": hour_end
        })
        return [dict(row) for row in result.mappings()]

    async def get_delivery_heatmap_by_store(self, store_id: int) -> List[Dict[str, Any]]:
        """
        Retorna métricas de entrega por bairro, com comparação semanal.
        Filtra regiões com pelo menos 10 entregas para evitar ruído.
        """
        query = text("""
        WITH current_week AS (
            SELECT 
                da.neighborhood,
                da.city,
                COUNT(*) AS delivery_count,
                AVG(s.delivery_seconds / 60.0) AS avg_minutes,
                PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY s.delivery_seconds / 60.0) AS p90_minutes
            FROM sales s
            JOIN delivery_addresses da ON da.sale_id = s.id
            WHERE s.store_id = :store_id
              AND s.sale_status_desc = 'COMPLETED'
              AND s.delivery_seconds IS NOT NULL
              AND s.created_at >= NOW() - INTERVAL '7 days'
            GROUP BY da.neighborhood, da.city
            HAVING COUNT(*) >= 10
        ),
        previous_week AS (
            SELECT 
                da.neighborhood,
                da.city,
                AVG(s.delivery_seconds / 60.0) AS avg_minutes
            FROM sales s
            JOIN delivery_addresses da ON da.sale_id = s.id
            WHERE s.store_id = :store_id
              AND s.sale_status_desc = 'COMPLETED'
              AND s.delivery_seconds IS NOT NULL
              AND s.created_at BETWEEN NOW() - INTERVAL '14 days' AND NOW() - INTERVAL '7 days'
            GROUP BY da.neighborhood, da.city
            HAVING COUNT(*) >= 10
        )
        SELECT 
            cw.neighborhood,
            cw.city,
            cw.delivery_count,
            ROUND(cw.avg_minutes::NUMERIC, 2) AS avg_delivery_minutes,
            ROUND(cw.p90_minutes::NUMERIC, 2) AS p90_delivery_minutes,
            ROUND(
                ((cw.avg_minutes - COALESCE(pw.avg_minutes, 0)) / NULLIF(pw.avg_minutes, 0) * 100)::NUMERIC, 2
            ) AS wow_change_pct
        FROM current_week cw
        LEFT JOIN previous_week pw 
          ON pw.neighborhood = cw.neighborhood AND pw.city = cw.city
        ORDER BY cw.avg_minutes DESC;
        """)
        result = await self.db.execute(query, {"store_id": store_id})
        return [dict(row) for row in result.mappings()]

    async def get_at_risk_customers(self, store_id: int) -> List[Dict[str, Any]]:
        """
        Clientes com ≥3 pedidos nos últimos 6 meses, mas sem compra nos últimos 30 dias.
        """
        query = text("""
        SELECT 
            COALESCE(s.customer_name, 'Cliente Anônimo') AS customer_name,
            s.customer_id,
            COUNT(*) AS total_orders,
            MAX(s.created_at)::DATE AS last_order_date,
            (CURRENT_DATE - MAX(s.created_at)::DATE) AS days_since_last_order
        FROM sales s
        WHERE s.store_id = :store_id
          AND s.customer_id IS NOT NULL
          AND s.sale_status_desc = 'COMPLETED'
          AND s.created_at >= CURRENT_DATE - INTERVAL '6 months'
        GROUP BY s.customer_id, s.customer_name
        HAVING COUNT(*) >= 3
          AND MAX(s.created_at) < CURRENT_DATE - INTERVAL '30 days'
        ORDER BY days_since_last_order DESC;
        """)
        result = await self.db.execute(query, {"store_id": store_id})
        return [dict(row) for row in result.mappings()]

    async def get_channel_performance(self, store_id: int, period_days: int = 30) -> List[Dict[str, Any]]:
        """
        Performance por canal: vendas, pedidos, ticket médio e distribuição horária.
        """
        query = text("""
        WITH base AS (
            SELECT 
                ch.name AS channel_name,
                s.total_amount,
                EXTRACT(HOUR FROM s.created_at) AS hour_of_day
            FROM sales s
            JOIN channels ch ON ch.id = s.channel_id
            WHERE s.store_id = :store_id
              AND s.sale_status_desc = 'COMPLETED'
              AND s.created_at >= NOW() - (:period_days || ' days')::INTERVAL
        )
        SELECT 
            channel_name,
            SUM(total_amount) AS total_sales,
            COUNT(*) AS total_orders,
            ROUND(AVG(total_amount), 2) AS average_ticket,
            json_object_agg(hour_of_day::TEXT, cnt) AS hourly_distribution
        FROM (
            SELECT 
                channel_name,
                total_amount,
                hour_of_day,
                COUNT(*) OVER (PARTITION BY channel_name, hour_of_day) AS cnt
            FROM base
        ) sub
        GROUP BY channel_name;
        """)
        # Nota: JSON aggregation requer cuidado — ajustar se necessário
        result = await self.db.execute(query, {"store_id": store_id, "period_days": period_days})
        return [dict(row) for row in result.mappings()]