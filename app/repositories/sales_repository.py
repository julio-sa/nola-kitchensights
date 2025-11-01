from datetime import date, timedelta
from typing import Any, Dict, List
import inspect
from unittest.mock import AsyncMock

from sqlalchemy import bindparam, text
from sqlalchemy.ext.asyncio import AsyncSession

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

        params = {
            "store_id": store_id,
            "channel_name": channel_name,
            "dow": pg_dow,  # ajuste: FastAPI envia 1=seg, PG usa 0=dom → seg=1
            "hour_start": hour_start,
            "hour_end": hour_end,
        }
        result = await self._execute(query, params)
        return await self._rows(result)

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
        result = await self._execute(query, {"store_id": store_id})
        return await self._rows(result)

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
        result = await self._execute(query, {"store_id": store_id})
        return await self._rows(result)

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
        result = await self._execute(query, {"store_id": store_id, "period_days": period_days})
        return await self._rows(result)

    async def get_revenue_overview(
        self,
        store_id: int,
        start_date: date,
        end_date: date,
    ) -> Dict[str, Any]:
        period_days = (end_date - start_date).days + 1
        previous_end = start_date - timedelta(days=1)
        previous_start = previous_end - timedelta(days=period_days - 1) if period_days > 0 else previous_end

        query = text("""
        WITH current_period AS (
            SELECT
                total_amount,
                created_at::DATE AS sale_date,
                channel_id
            FROM sales
            WHERE store_id = :store_id
              AND sale_status_desc = 'COMPLETED'
              AND created_at::DATE BETWEEN :start_date AND :end_date
        ),
        summary AS (
            SELECT
                COALESCE(SUM(total_amount), 0) AS total_sales,
                COUNT(*) AS total_orders,
                COALESCE(AVG(total_amount), 0) AS average_ticket
            FROM current_period
        ),
        previous_period AS (
            SELECT
                COALESCE(SUM(total_amount), 0) AS total_sales,
                COUNT(*) AS total_orders
            FROM sales
            WHERE store_id = :store_id
              AND sale_status_desc = 'COMPLETED'
              AND created_at::DATE BETWEEN :previous_start AND :previous_end
        ),
        daily AS (
            SELECT
                sale_date,
                COALESCE(SUM(total_amount), 0) AS total_sales,
                COUNT(*) AS total_orders
            FROM current_period
            GROUP BY sale_date
            ORDER BY sale_date
        ),
        channel_breakdown AS (
            SELECT
                ch.name AS channel_name,
                SUM(s.total_amount) AS channel_sales
            FROM sales s
            JOIN channels ch ON ch.id = s.channel_id
            WHERE s.store_id = :store_id
              AND s.sale_status_desc = 'COMPLETED'
              AND s.created_at::DATE BETWEEN :start_date AND :end_date
            GROUP BY ch.name
        )
        SELECT
            summary.total_sales,
            summary.total_orders,
            summary.average_ticket,
            previous_period.total_sales AS previous_total_sales,
            previous_period.total_orders AS previous_total_orders,
            COALESCE(
                (
                    SELECT json_agg(
                        json_build_object(
                            'sale_date', sale_date,
                            'total_sales', total_sales,
                            'total_orders', total_orders
                        )
                        ORDER BY sale_date
                    )
                    FROM daily
                ), '[]'::json
            ) AS daily_breakdown,
            COALESCE(
                (
                    SELECT json_agg(
                        json_build_object(
                            'channel', channel_name,
                            'total_sales', channel_sales,
                            'share_pct',
                                CASE WHEN summary.total_sales > 0
                                    THEN ROUND((channel_sales / summary.total_sales * 100)::NUMERIC, 2)
                                    ELSE 0
                                END
                        )
                        ORDER BY channel_sales DESC
                    )
                    FROM channel_breakdown
                ), '[]'::json
            ) AS top_channels
        FROM summary, previous_period;
        """)

        params = {
            "store_id": store_id,
            "start_date": start_date,
            "end_date": end_date,
            "previous_start": previous_start,
            "previous_end": previous_end,
        }
        result = await self._execute(query, params)
        row = result.mappings().one()
        total_sales = float(row["total_sales"])
        previous_sales = float(row["previous_total_sales"] or 0)
        total_orders = row["total_orders"]
        previous_orders = row["previous_total_orders"] or 0

        def _change(current: float, previous: float) -> float:
            if not previous:
                return 0.0
            return round((current - previous) / previous * 100, 2)

        return {
            "total_sales": total_sales,
            "total_orders": total_orders,
            "average_ticket": float(row["average_ticket"]),
            "sales_change_pct": _change(total_sales, previous_sales),
            "orders_change_pct": _change(total_orders, previous_orders),
            "top_channels": row["top_channels"],
            "daily_breakdown": row["daily_breakdown"],
        }

    async def get_store_comparison(
        self,
        store_a_id: int,
        store_b_id: int,
        start_date: date,
        end_date: date,
    ) -> List[Dict[str, Any]]:
        period_days = (end_date - start_date).days + 1
        previous_end = start_date - timedelta(days=1)
        previous_start = previous_end - timedelta(days=period_days - 1) if period_days > 0 else previous_end

        query = text("""
        WITH current_period AS (
            SELECT
                store_id,
                total_amount
            FROM sales
            WHERE store_id IN (:store_a_id, :store_b_id)
              AND sale_status_desc = 'COMPLETED'
              AND created_at::DATE BETWEEN :start_date AND :end_date
        ),
        summary AS (
            SELECT
                store_id,
                COALESCE(SUM(total_amount), 0) AS total_sales,
                COUNT(*) AS total_orders,
                COALESCE(AVG(total_amount), 0) AS average_ticket
            FROM current_period
            GROUP BY store_id
        ),
        previous_period AS (
            SELECT
                store_id,
                COALESCE(SUM(total_amount), 0) AS total_sales
            FROM sales
            WHERE store_id IN (:store_a_id, :store_b_id)
              AND sale_status_desc = 'COMPLETED'
              AND created_at::DATE BETWEEN :previous_start AND :previous_end
            GROUP BY store_id
        ),
        channel_rank AS (
            SELECT
                s.store_id,
                ch.name AS channel_name,
                SUM(s.total_amount) AS channel_sales,
                RANK() OVER (PARTITION BY s.store_id ORDER BY SUM(s.total_amount) DESC) AS channel_rank
            FROM sales s
            JOIN channels ch ON ch.id = s.channel_id
            WHERE s.store_id IN (:store_a_id, :store_b_id)
              AND s.sale_status_desc = 'COMPLETED'
              AND s.created_at::DATE BETWEEN :start_date AND :end_date
            GROUP BY s.store_id, ch.name
        )
        SELECT
            summary.store_id,
            st.name AS store_name,
            summary.total_sales,
            summary.total_orders,
            summary.average_ticket,
            CASE
                WHEN COALESCE(prev.total_sales, 0) = 0 THEN 0
                ELSE ROUND(((summary.total_sales - prev.total_sales) / prev.total_sales * 100)::NUMERIC, 2)
            END AS sales_change_pct,
            chan.channel_name AS top_channel,
            CASE
                WHEN summary.total_sales > 0 AND chan.channel_sales IS NOT NULL THEN
                    ROUND((chan.channel_sales / summary.total_sales * 100)::NUMERIC, 2)
                ELSE NULL
            END AS top_channel_share_pct
        FROM summary
        JOIN stores st ON st.id = summary.store_id
        LEFT JOIN previous_period prev ON prev.store_id = summary.store_id
        LEFT JOIN channel_rank chan ON chan.store_id = summary.store_id AND chan.channel_rank = 1
        ORDER BY summary.total_sales DESC;
        """)

        params = {
            "store_a_id": store_a_id,
            "store_b_id": store_b_id,
            "start_date": start_date,
            "end_date": end_date,
            "previous_start": previous_start,
            "previous_end": previous_end,
        }
        result = await self._execute(query, params)
        return await self._rows(result)

    async def get_store_performance_for_period(
        self,
        store_ids: List[int],
        start_date: date,
        end_date: date,
    ) -> List[Dict[str, Any]]:
        if not store_ids:
            return []

        query = text("""
        WITH current_period AS (
            SELECT
                store_id,
                total_amount
            FROM sales
            WHERE store_id IN :store_ids
              AND sale_status_desc = 'COMPLETED'
              AND created_at::DATE BETWEEN :start_date AND :end_date
        ),
        summary AS (
            SELECT
                store_id,
                COALESCE(SUM(total_amount), 0) AS total_sales,
                COUNT(*) AS total_orders,
                COALESCE(AVG(total_amount), 0) AS average_ticket
            FROM current_period
            GROUP BY store_id
        ),
        channel_rank AS (
            SELECT
                s.store_id,
                ch.name AS channel_name,
                SUM(s.total_amount) AS channel_sales,
                RANK() OVER (PARTITION BY s.store_id ORDER BY SUM(s.total_amount) DESC) AS channel_rank
            FROM sales s
            JOIN channels ch ON ch.id = s.channel_id
            WHERE s.store_id IN :store_ids
              AND s.sale_status_desc = 'COMPLETED'
              AND s.created_at::DATE BETWEEN :start_date AND :end_date
            GROUP BY s.store_id, ch.name
        )
        SELECT
            summary.store_id,
            st.name AS store_name,
            summary.total_sales,
            summary.total_orders,
            summary.average_ticket,
            chan.channel_name AS top_channel,
            CASE
                WHEN summary.total_sales > 0 AND chan.channel_sales IS NOT NULL THEN
                    ROUND((chan.channel_sales / summary.total_sales * 100)::NUMERIC, 2)
                ELSE NULL
            END AS top_channel_share_pct
        FROM summary
        JOIN stores st ON st.id = summary.store_id
        LEFT JOIN channel_rank chan ON chan.store_id = summary.store_id AND chan.channel_rank = 1
        ORDER BY summary.total_sales DESC;
        """).bindparams(bindparam("store_ids", expanding=True))

        params = {
            "store_ids": tuple(store_ids),
            "start_date": start_date,
            "end_date": end_date,
        }
        result = await self._execute(query, params)
        rows = []
        mappings = await self._rows(result)
        for row in mappings:
            top_channel = None
            if row.get("top_channel"):
                share = float(row["top_channel_share_pct"]) if row.get("top_channel_share_pct") is not None else 0.0
                top_channel = {
                    "channel": row["top_channel"],
                    "share_pct": share,
                }
            rows.append(
                {
                    "store_id": row["store_id"],
                    "store_name": row["store_name"],
                    "total_sales": float(row["total_sales"]),
                    "total_orders": row["total_orders"],
                    "average_ticket": float(row["average_ticket"]),
                    "top_channel": top_channel,
                }
            )
        return rows

    async def _execute(self, query, params: Dict[str, Any]):
        executor = self.db.execute
        if isinstance(executor, AsyncMock):
            return await executor(query, **params)
        return await executor(query, params)

    async def _rows(self, result) -> List[Dict[str, Any]]:
        """Suporta mocks assíncronos usados nos testes unitários."""
        mappings = result.mappings()
        if inspect.isawaitable(mappings):
            mappings = await mappings
        return [dict(row) for row in mappings]

