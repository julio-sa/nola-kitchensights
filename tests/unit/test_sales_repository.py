import pytest
from unittest.mock import AsyncMock
from app.repositories.sales_repository import SalesRepository

@pytest.mark.asyncio
async def test_get_top_products_query_executes_with_correct_params():
    """
    Verifica que o repositório chama a query com os parâmetros corretos.
    Não testa SQL real — apenas a interface.
    """
    # Mock da sessão do SQLAlchemy
    mock_session = AsyncMock()
    mock_result = AsyncMock()
    mock_result.mappings.return_value = []
    mock_session.execute.return_value = mock_result

    repo = SalesRepository(db=mock_session)

    await repo.get_top_products_by_channel_and_time(
        store_id=5,
        channel_name="Rappi",
        day_of_week=4,  # quinta
        hour_start=18,
        hour_end=22
    )

    # Verifica que execute foi chamado com a query e parâmetros esperados
    mock_session.execute.assert_awaited_once()
    call_args = mock_session.execute.call_args
    params = call_args[1]  # kwargs

    assert params["store_id"] == 5
    assert params["channel_name"] == "Rappi"
    assert params["dow"] == 4 % 7  # ajuste para PostgreSQL (0=dom)
    assert params["hour_start"] == 18
    assert params["hour_end"] == 22