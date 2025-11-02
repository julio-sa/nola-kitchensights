# tests/test_sales_repo_top_products_unit.py
import pytest
from unittest.mock import AsyncMock
from app.repositories.sales_repository import SalesRepository

@pytest.mark.asyncio
async def test_get_top_products_calls_execute_with_kwargs():
    # mock da sessão
    mock_session = AsyncMock()
    mock_result = AsyncMock()
    # o repo faz result.mappings(), então precisamos disso
    mock_result.mappings.return_value = []
    mock_session.execute.return_value = mock_result

    repo = SalesRepository(db=mock_session)

    await repo.get_top_products_by_channel_and_time(
        store_id=5,
        channel_name="Rappi",
        day_of_week=4,
        hour_start=18,
        hour_end=22,
    )

    # como _execute detecta AsyncMock, ele chama:
    # await mock_session.execute(query, **params)
    mock_session.execute.assert_awaited_once()

    awaited = mock_session.execute.await_args
    args, kwargs = awaited.args, awaited.kwargs

    # 1) veio um text(...) como primeiro arg
    assert len(args) == 1, "esperava só o objeto da query como arg posicional"
    # 2) os parâmetros vieram como kwargs
    assert kwargs["store_id"] == 5
    assert kwargs["channel_name"] == "Rappi"
    # o repo faz (day_of_week % 7)
    assert kwargs["dow"] == (4 % 7)
    assert kwargs["hour_start"] == 18
    assert kwargs["hour_end"] == 22
