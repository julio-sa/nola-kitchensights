# tests/test_sales_repo_delivery_heatmap_integration.py
import os
import asyncio
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

from app.repositories.sales_repository import SalesRepository


def test_get_delivery_heatmap_real_db():
    """
    Teste de integração REAL: bate no Postgres que está rodando no docker.
    Feito síncrono de propósito pra não bater de frente com o conftest async.
    """
    asyncio.run(_run_delivery_heatmap_test())


async def _run_delivery_heatmap_test():
    # pega o mesmo DATABASE_URL do .env
    raw_url = os.getenv(
        "DATABASE_URL",
        "postgresql://challenge:challenge@localhost:5432/challenge_db",
    )
    # SQLAlchemy async precisa desse prefixo
    async_url = raw_url.replace("postgresql://", "postgresql+asyncpg://")

    engine = create_async_engine(async_url, echo=False, future=True)
    async_session_maker = sessionmaker(
        engine, expire_on_commit=False, class_=AsyncSession
    )

    async with async_session_maker() as session:
        repo = SalesRepository(session)
        rows = await repo.get_delivery_heatmap_by_store(store_id=1)

    # o teste não precisa que tenha dado — o importante é NÃO quebrar
    assert rows is not None
    assert isinstance(rows, list)

    # se tiver pelo menos 1 linha, checa o formato
    if rows:
        first = rows[0]
        assert "neighborhood" in first
        assert "city" in first
        assert "delivery_count" in first
        assert "avg_delivery_minutes" in first
