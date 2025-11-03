# app/repositories/sales_repository.py
from __future__ import annotations

from datetime import date, timedelta
from typing import Any, Dict, List, Optional

from sqlalchemy import text, bindparam
from sqlalchemy.ext.asyncio import AsyncSession


class SalesRepository:
    """
    Camada de acesso a dados.
    Tudo que é SQL direto fica aqui.
    """

    def __init__(self, db: AsyncSession):
        self.db = db

    # ---------------------------------------------------------
    # helpers básicos
    # ---------------------------------------------------------
    async def _execute(self, query, params: Dict[str, Any]):
        result = await self.db.execute(query, params)
        return result

    async def _rows(self, result) -> List[Dict[str, Any]]:
        return [dict(r) for r in result.mappings().all()]

    async def _get_last_sale_date_for_stores(self, store_ids: list[int]) -> Optional[date]:
        """
        usado como fallback quando o período pedido não tem dado
        """
        if not store_ids:
            return None

        q = (
            text(
                """
            SELECT MAX(created_at)::DATE AS last_date
            FROM sales
            WHERE store_id IN :store_ids
              AND sale_status_desc = 'COMPLETED'
            """
            )
            .bindparams(bindparam("store_ids", expanding=True))
        )

        res = await self._execute(q, {"store_ids": tuple(store_ids)})
        rows = await self._rows(res)
        if not rows:
            return None
        return rows[0].get("last_date")

    # ---------------------------------------------------------
    # TOP PRODUCTS
    # ---------------------------------------------------------
    async def get_top_products_by_channel_and_time(
        self,
        store_id: int,
        channel: str,
        day_of_week: int,
        hour_start: int,
        hour_end: int,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        limit: int = 5,
    ) -> list[dict[str, Any]]:
        """
        tua versão "simples": canal + dia + hora
        se vier start/end, considera o período
        """
        channel = channel.strip()
        pg_dow = day_of_week % 7  # 1..7 → 0..6

        if start_date and end_date:
            sql = text(
                """
                WITH base AS (
                    SELECT
                        p.name AS product_name,
                        ps.quantity AS qty,
                        ps.total_price AS revenue
                    FROM sales s
                    JOIN channels c ON c.id = s.channel_id
                    JOIN product_sales ps ON ps.sale_id = s.id
                    JOIN products p ON p.id = ps.product_id
                    WHERE
                        s.store_id = :store_id
                        AND c.name = :channel
                        AND s.sale_status_desc = 'COMPLETED'
                        AND s.created_at::date BETWEEN :start_date AND :end_date
                )
                SELECT
                    product_name,
                    SUM(qty) AS total_quantity,
                    SUM(revenue) AS total_revenue,
                    100 * SUM(revenue) / NULLIF(SUM(SUM(revenue)) OVER (), 0) AS pct_of_total
                FROM base
                GROUP BY product_name
                ORDER BY total_revenue DESC
                LIMIT :limit
                """
            )
            params = {
                "store_id": store_id,
                "channel": channel,
                "start_date": start_date,
                "end_date": end_date,
                "limit": limit,
            }
        else:
            sql = text(
                """
                WITH base AS (
                    SELECT
                        p.name AS product_name,
                        ps.quantity AS qty,
                        ps.total_price AS revenue
                    FROM sales s
                    JOIN channels c ON c.id = s.channel_id
                    JOIN product_sales ps ON ps.sale_id = s.id
                    JOIN products p ON p.id = ps.product_id
                    WHERE
                        s.store_id = :store_id
                        AND c.name = :channel
                        AND s.sale_status_desc = 'COMPLETED'
                        AND EXTRACT(DOW FROM s.created_at) = :pg_dow
                        AND EXTRACT(HOUR FROM s.created_at) BETWEEN :hour_start AND :hour_end
                )
                SELECT
                    product_name,
                    SUM(qty) AS total_quantity,
                    SUM(revenue) AS total_revenue,
                    100 * SUM(revenue) / NULLIF(SUM(SUM(revenue)) OVER (), 0) AS pct_of_total
                FROM base
                GROUP BY product_name
                ORDER BY total_revenue DESC
                LIMIT :limit
                """
            )
            params = {
                "store_id": store_id,
                "channel": channel,
                "pg_dow": pg_dow,
                "hour_start": hour_start,
                "hour_end": hour_end,
                "limit": limit,
            }

        result = await self._execute(sql, params)
        return await self._rows(result)

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
    ) -> List[Dict[str, Any]]:
        """
        versão que teu Flutter vai usar qdo o usuário abrir o popup de filtros
        (canal, dia da semana, faixa de horário)
        """
        period_days = (end_date - start_date).days + 1
        prev_end = start_date - timedelta(days=1)
        prev_start = prev_end - timedelta(days=period_days - 1)

        filters = ["s.store_id = :store_id", "s.sale_status_desc = 'COMPLETED'"]
        prev_filters = ["s.store_id = :store_id", "s.sale_status_desc = 'COMPLETED'"]

        if channel_name:
            filters.append("ch.name = :channel_name")
            prev_filters.append("ch.name = :channel_name")

        if day_of_week is not None:
            pg_dow = day_of_week % 7
            filters.append("EXTRACT(DOW FROM s.created_at) = :dow")
            prev_filters.append("EXTRACT(DOW FROM s.created_at) = :dow")

        if hour_start is not None and hour_end is not None:
            filters.append("EXTRACT(HOUR FROM s.created_at) BETWEEN :hour_start AND :hour_end")
            prev_filters.append("EXTRACT(HOUR FROM s.created_at) BETWEEN :hour_start AND :hour_end")

        filters.append("s.created_at::DATE BETWEEN :start_date AND :end_date")
        prev_filters.append("s.created_at::DATE BETWEEN :prev_start AND :prev_end")

        where_current = " AND ".join(filters)
        where_prev = " AND ".join(prev_filters)

        query = text(f"""
        WITH current_period AS (
            SELECT 
                p.name AS product_name,
                SUM(ps.quantity) AS total_quantity,
                SUM(ps.total_price) AS total_revenue
            FROM sales s
            JOIN channels ch ON ch.id = s.channel_id
            JOIN product_sales ps ON ps.sale_id = s.id
            JOIN products p ON p.id = ps.product_id
            WHERE {where_current}
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
            WHERE {where_prev}
            GROUP BY p.name
        ),
        totals AS (
            SELECT COALESCE(SUM(total_revenue), 0) AS total_rev
            FROM current_period
        )
        SELECT 
            cp.product_name,
            cp.total_quantity,
            cp.total_revenue,
            CASE 
                WHEN t.total_rev > 0 THEN ROUND((cp.total_revenue / t.total_rev * 100)::NUMERIC, 2)
                ELSE 0
            END AS pct_of_total,
            CASE 
                WHEN pp.total_quantity IS NULL OR pp.total_quantity = 0 THEN NULL
                ELSE ROUND(
                    ((cp.total_quantity - pp.total_quantity)::DECIMAL / pp.total_quantity * 100)::NUMERIC, 2
                )
            END AS wow_change_pct
        FROM current_period cp
        CROSS JOIN totals t
        LEFT JOIN previous_period pp ON pp.product_name = cp.product_name
        ORDER BY cp.total_revenue DESC
        LIMIT :limit;
        """)

        params: Dict[str, Any] = {
            "store_id": store_id,
            "start_date": start_date,
            "end_date": end_date,
            "prev_start": prev_start,
            "prev_end": prev_end,
            "limit": limit,
        }
        if channel_name:
            params["channel_name"] = channel_name
        if day_of_week is not None:
            params["dow"] = day_of_week % 7
        if hour_start is not None and hour_end is not None:
            params["hour_start"] = hour_start
            params["hour_end"] = hour_end

        res = await self._execute(query, params)
        return await self._rows(res)

    # ---------------------------------------------------------
    # DELIVERY HEATMAP
    # ---------------------------------------------------------
    async def get_delivery_heatmap_by_store(
        self,
        store_id: int,
        start_date: Optional[date],
        end_date: Optional[date],
    ) -> List[Dict[str, Any]]:
        if end_date is None:
            end_date = date.today()
        if start_date is None:
            start_date = end_date.replace(day=1)

        sql = text(
            """
            SELECT
                COALESCE(da.neighborhood, 'Sem bairro') AS neighborhood,
                COALESCE(da.city, 'Sem cidade')         AS city,
                COUNT(*)                                 AS delivery_count,
                AVG(s.delivery_seconds)                  AS avg_delivery_seconds
            FROM sales s
            JOIN delivery_addresses da ON da.sale_id = s.id
            WHERE s.store_id = :store_id
              AND s.sale_status_desc = 'COMPLETED'
              AND s.created_at::date BETWEEN :start_date AND :end_date
            GROUP BY COALESCE(da.neighborhood, 'Sem bairro'),
                     COALESCE(da.city, 'Sem cidade')
            ORDER BY delivery_count DESC
            """
        )
        res = await self._execute(
            sql,
            {
                "store_id": store_id,
                "start_date": start_date,
                "end_date": end_date,
            },
        )
        return await self._rows(res)

    # ---------------------------------------------------------
    # AT RISK CUSTOMERS
    # ---------------------------------------------------------
    async def get_at_risk_customers(self, store_id: int) -> List[Dict[str, Any]]:
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
        HAVING COUNT(*) >= 2
          AND MAX(s.created_at) < CURRENT_DATE - INTERVAL '30 days'
        ORDER BY days_since_last_order DESC;
        """)
        res = await self._execute(query, {"store_id": store_id})
        return await self._rows(res)

    # ---------------------------------------------------------
    # CHANNELS e STORES
    # ---------------------------------------------------------
    async def list_channels_for_store(self, store_id: int):
        sql = text("""
            SELECT DISTINCT ch.id, ch.name
            FROM sales s
            JOIN channels ch ON ch.id = s.channel_id
            WHERE s.store_id = :store_id
            ORDER BY ch.name
        """)
        res = await self._execute(sql, {"store_id": store_id})
        return await self._rows(res)

    async def list_available_stores(self, limit: int = 50) -> List[Dict[str, Any]]:
        """
        AQUI já devolve o NOME da loja.
        É isso que o Flutter quer.
        """
        sql = text("""
            SELECT
                st.id   AS store_id,
                st.name AS store_name
            FROM stores st
            ORDER BY st.name
            LIMIT :limit
        """)
        res = await self._execute(sql, {"limit": limit})
        return await self._rows(res)

    # ---------------------------------------------------------
    # REVENUE OVERVIEW
    # ---------------------------------------------------------
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
        res = await self._execute(query, params)
        row = (await self._rows(res))[0]

        def _change(current: float, previous: float) -> float:
            if not previous:
                return 0.0
            return round((current - previous) / previous * 100, 2)

        total_sales = float(row["total_sales"])
        total_orders = row["total_orders"]
        previous_sales = float(row["previous_total_sales"] or 0)
        previous_orders = row["previous_total_orders"] or 0

        return {
            "total_sales": total_sales,
            "total_orders": total_orders,
            "average_ticket": float(row["average_ticket"]),
            "sales_change_pct": _change(total_sales, previous_sales),
            "orders_change_pct": _change(total_orders, previous_orders),
            "top_channels": row["top_channels"],
            "daily_breakdown": row["daily_breakdown"],
        }

    # ---------------------------------------------------------
    # STORE PERFORMANCE
    # ---------------------------------------------------------
    async def get_channel_performance(self, store_id: int, period_days: int = 30):
        q = text("""
            SELECT ch.name AS channel, SUM(s.total_amount) AS total_sales
            FROM sales s
            JOIN channels ch ON ch.id = s.channel_id
            WHERE s.store_id = :store_id
              AND s.sale_status_desc = 'COMPLETED'
              AND s.created_at::date >= CURRENT_DATE - :period_days * INTERVAL '1 day'
            GROUP BY ch.name
            ORDER BY total_sales DESC
        """)
        res = await self._execute(q, {"store_id": store_id, "period_days": period_days})
        return await self._rows(res)

    # ---------------------------------------------------------
    # STORE COMPARISON (COM NOME)
    # ---------------------------------------------------------
    async def get_store_comparison(
        self,
        store_a_id: int,
        store_b_id: int,
        start_date: date,
        end_date: date,
    ) -> List[Dict[str, Any]]:
        """
        O MESMO endpoint que você já tinha,
        mas agora faz JOIN em stores pra trazer store_name.
        """
        # período anterior do mesmo tamanho
        period_days = (end_date - start_date).days + 1
        prev_end = start_date - timedelta(days=1)
        prev_start = prev_end - timedelta(days=period_days - 1)

        query = text("""
        WITH current_period AS (
            SELECT
                s.store_id,
                s.total_amount
            FROM sales s
            WHERE s.sale_status_desc = 'COMPLETED'
              AND s.store_id IN (:store_a_id, :store_b_id)
              AND s.created_at::DATE BETWEEN :start_date AND :end_date
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
                s.store_id,
                COALESCE(SUM(s.total_amount), 0) AS total_sales
            FROM sales s
            WHERE s.sale_status_desc = 'COMPLETED'
              AND s.store_id IN (:store_a_id, :store_b_id)
              AND s.created_at::DATE BETWEEN :prev_start AND :prev_end
            GROUP BY s.store_id
        ),
        channel_rank AS (
            SELECT
                s.store_id,
                ch.name AS channel_name,
                SUM(s.total_amount) AS channel_sales,
                RANK() OVER (PARTITION BY s.store_id ORDER BY SUM(s.total_amount) DESC) AS channel_rank
            FROM sales s
            JOIN channels ch ON ch.id = s.channel_id
            WHERE s.sale_status_desc = 'COMPLETED'
              AND s.store_id IN (:store_a_id, :store_b_id)
              AND s.created_at::DATE BETWEEN :start_date AND :end_date
            GROUP BY s.store_id, ch.name
        )
        SELECT
            sum.store_id,
            st.name AS store_name,
            sum.total_sales,
            sum.total_orders,
            sum.average_ticket,
            CASE
                WHEN COALESCE(prev.total_sales, 0) = 0 THEN 0
                ELSE ROUND(((sum.total_sales - prev.total_sales) / prev.total_sales * 100)::NUMERIC, 2)
            END AS sales_change_pct,
            cr.channel_name AS top_channel,
            CASE
                WHEN sum.total_sales > 0 AND cr.channel_sales IS NOT NULL THEN
                    ROUND((cr.channel_sales / sum.total_sales * 100)::NUMERIC, 2)
                ELSE NULL
            END AS top_channel_share_pct
        FROM summary sum
        JOIN stores st ON st.id = sum.store_id
        LEFT JOIN previous_period prev ON prev.store_id = sum.store_id
        LEFT JOIN channel_rank cr ON cr.store_id = sum.store_id AND cr.channel_rank = 1
        ORDER BY sum.total_sales DESC;
        """)

        params = {
            "store_a_id": store_a_id,
            "store_b_id": store_b_id,
            "start_date": start_date,
            "end_date": end_date,
            "prev_start": prev_start,
            "prev_end": prev_end,
        }
        res = await self._execute(query, params)
        return await self._rows(res)
