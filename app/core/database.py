# Conexão assíncrona com PostgreSQL usando SQLAlchemy Core + asyncpg
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.pool import NullPool
import os
from dotenv import load_dotenv

load_dotenv()

# URL de conexão do banco fornecido no desafio.
# Aceita tanto esquemas síncronos quanto assíncronos e converte automaticamente
# para o driver asyncpg esperado pelo SQLAlchemy assíncrono.
raw_url = os.getenv("DATABASE_URL", "postgresql://challenge:challenge@localhost:5432/challenge_db")
if raw_url.startswith("postgresql://"):
    DATABASE_URL = raw_url.replace("postgresql://", "postgresql+asyncpg://", 1)
else:
    DATABASE_URL = raw_url

# Engine sem pool (ótimo para ambientes serverless ou dev leve)
engine = create_async_engine(DATABASE_URL, echo=False, poolclass=NullPool)

async def get_db_session():
    """
    Dependência para injeção de sessão de banco em endpoints.
    Garante que cada requisição tenha sua própria transação.
    """
    async with AsyncSession(engine) as session:
        yield session