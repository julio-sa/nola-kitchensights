# tests/test_sales_repo_revenue_overview_integration.py
import os
import asyncio
from datetime import date, timedelta
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

from app.repositories.sales_repository import SalesRepository


def test_get_revenue_overview_real_db():
    """
    Teste de integração REAL para o resumo de faturamento.
    Também síncrono pra não brigar com o conftest.
    """
    asyncio.run(_run_revenue_overview_test())


async def _run_revenue_overview_test():
    raw_url = os.getenv(
        "DATABASE_URL",
        "postgresql://challenge:challenge@localhost:5432/challenge_db",
    )
    async_url = raw_url.replace("postgresql://", "postgresql+asyncpg://")

    engine = create_async_engine(async_url, echo=False, future=True)
    async_session_maker = sessionmaker(
        engine, expire_on_commit=False, class_=AsyncSession
    )

    today = date.today()
    start = today - timedelta(days=7)

    async with async_session_maker() as session:
        repo = SalesRepository(session)
        overview = await repo.get_revenue_overview(
            store_id=1,
            start_date=start,
            end_date=today,
        )

    assert overview is not None
    # o repo sempre devolve esse formato
    assert "total_sales" in overview
    assert "total_orders" in overview
    assert "average_ticket" in overview
    assert "daily_breakdown" in overview
    assert "top_channels" in overview
