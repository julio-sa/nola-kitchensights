import pytest
from unittest.mock import AsyncMock
from app.services.widget_service import WidgetService
from app.models.widgets import TopProductsResponse

@pytest.mark.asyncio
async def test_get_top_products_insight_transforms_data_correctly():
    """
    Garante que o WidgetService transforma corretamente os dados brutos do repositório
    em um modelo Pydantic válido com insights interpretáveis.
    """
    # Arrange: mock do repositório
    mock_repo = AsyncMock()
    mock_repo.get_top_products_by_channel_and_time.return_value = [
        {
            "product_name": "X-Bacon",
            "total_quantity": 120,
            "total_revenue": 3600.0,
            "pct_of_total": 25.5,
            "wow_change_pct": 12.3
        },
        {
            "product_name": "Batata Frita",
            "total_quantity": 95,
            "total_revenue": 1710.0,
            "pct_of_total": 12.0,
            "wow_change_pct": None  # primeiro dado da série
        }
    ]

    service = WidgetService(repository=mock_repo)

    # Act
    result = await service.get_top_products_insight(
        store_id=1,
        channel="iFood",
        day_of_week=5,  # sexta
        hour_start=19,
        hour_end=23
    )

    # Assert
    assert isinstance(result, TopProductsResponse)
    assert result.store_id == 1
    assert result.channel == "iFood"
    assert len(result.products) == 2

    first = result.products[0]
    assert first["product_name"] == "X-Bacon"
    assert first["total_quantity_sold"] == 120
    assert first["total_revenue"] == 3600.0
    assert first["percentage_of_total"] == 25.5
    assert first["week_over_week_change_pct"] == 12.3

    second = result.products[1]
    assert second["week_over_week_change_pct"] is None


@pytest.mark.asyncio
async def test_get_at_risk_customers_handles_empty_result():
    """Testa cenário onde não há clientes em risco."""
    mock_repo = AsyncMock()
    mock_repo.get_at_risk_customers.return_value = []

    service = WidgetService(repository=mock_repo)
    result = await service.get_at_risk_customers_insight(store_id=2)

    assert result.store_id == 2
    assert result.customers == []