# tests/test_sales_repo_top_products_integration.py
import os
import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

from app.repositories.sales_repository import SalesRepository

# 1) pegar a URL síncrona do .env
RAW_DB_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://challenge:challenge@localhost:5432/challenge_db",
)

# 2) converter para URL assíncrona
ASYNC_DB_URL = RAW_DB_URL.replace("postgresql://", "postgresql+asyncpg://")

# 3) criar engine global (teste simples, ok ser global)
engine = create_async_engine(ASYNC_DB_URL, echo=False, future=True)

# 4) criar Session factory
AsyncSessionLocal = sessionmaker(
    engine,
    expire_on_commit=False,
    class_=AsyncSession,
)


@pytest_asyncio.fixture
async def db_session():
    """
    Entrega uma AsyncSession REAL para o teste.
    """
    async with AsyncSessionLocal() as session:
        yield session
    # não vamos dar dispose aqui pra não fechar a engine a cada teste;
    # se quiser muito fechar, dá pra fazer:
    # await engine.dispose()


@pytest.mark.asyncio
async def test_get_top_products_real_db(db_session: AsyncSession):
    """
    Teste de integração: chama o Postgres da máquina (Docker)
    e garante que a query roda sem explodir.
    """
    repo = SalesRepository(db_session)

    rows = await repo.get_top_products_by_channel_and_time(
        store_id=1,
        channel_name="iFood",  # troque para o NOME REAL do canal na sua tabela
        day_of_week=5,         # sexta
        hour_start=18,
        hour_end=23,
    )

    # o importante: não quebrou e veio uma lista
    assert rows is not None
    assert isinstance(rows, list)

    # se tiver dado, validamos o shape básico
    if rows:
        first = rows[0]
        assert "product_name" in first
        assert "total_quantity" in first
        assert "total_revenue" in first
