from __future__ import annotations

from datetime import date, datetime
from io import StringIO
from typing import Iterable

from fastapi import HTTPException

from app.repositories.sales_repository import SalesRepository


class ReportService:
    """Gera relatórios executivos em CSV a partir dos dados de vendas."""

    def __init__(self, repository: SalesRepository) -> None:
        self.repo = repository

    async def build_store_performance_report(
        self,
        store_ids: Iterable[int],
        start_date: str,
        end_date: str,
    ) -> tuple[str, str]:
        try:
            start = date.fromisoformat(start_date)
            end = date.fromisoformat(end_date)
        except ValueError as exc:  # pragma: no cover - validação defensiva
            raise HTTPException(status_code=400, detail="Datas inválidas") from exc

        if start > end:
            raise HTTPException(status_code=400, detail="Data inicial deve ser anterior à final")

        store_metrics = await self.repo.get_store_performance_for_period(
            store_ids=list(store_ids),
            start_date=start,
            end_date=end,
        )

        if not store_metrics:
            raise HTTPException(status_code=404, detail="Nenhum dado encontrado para o período informado")

        output = StringIO()
        header = [
            "Loja",
            "Faturamento",
            "Pedidos",
            "Ticket Médio",
            "Canal líder",
            "Participação canal líder (%)",
        ]
        output.write(";".join(header) + "\n")

        for metric in store_metrics:
            top_channel = metric["top_channel"] or {}
            output.write(
                ";".join(
                    [
                        metric["store_name"],
                        f"{metric['total_sales']:.2f}",
                        str(metric["total_orders"]),
                        f"{metric['average_ticket']:.2f}",
                        top_channel.get("channel", "-"),
                        f"{top_channel.get('share_pct', 0.0):.1f}",
                    ]
                )
                + "\n"
            )

        filename = f"store-performance_{start.strftime('%Y%m%d')}_{end.strftime('%Y%m%d')}.csv"
        generated_at = datetime.now().isoformat(timespec="seconds")
        output.write(f"Gerado em;{generated_at}\n")

        return output.getvalue(), filename
