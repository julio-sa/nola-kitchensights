# tests/test_widgets.py
import pytest
from fastapi.testclient import TestClient
from app.main import app  # importa o FastAPI app da sua aplicação


# Fake do serviço que o endpoint usa
class FakeWidgetService:
    async def get_revenue_overview(self, store_id: int, start_date, end_date):
        return {
            "total_sales": 12345.67,
            "total_orders": 321,
            "average_ticket": 38.45,
            "sales_change_pct": -12.3,
            "orders_change_pct": -3.1,
            "start_date": "2025-10-01",
            "end_date": "2025-10-31",
            "top_channels": [
                {"channel": "iFood", "share_pct": 62.5},
                {"channel": "Rappi", "share_pct": 23.0},
            ],
        }


@pytest.fixture(autouse=True)
def override_deps():
    # IMPORTANTE: use a mesma função de Depends do seu router
    # Ajuste o import abaixo se o caminho do seu projeto diferir:
    from app.api.v1.routes.widgets import get_widget_service

    app.dependency_overrides[get_widget_service] = lambda: FakeWidgetService()
    yield
    app.dependency_overrides.clear()


def test_revenue_overview_ok():
    client = TestClient(app)
    # Seu backend expõe /api/v1/widgets/... (mesmo caminho usado no Flutter)
    url = "/api/v1/widgets/revenue-overview"

    r = client.get(
        url,
        params={
            "store_id": 1,
            "start_date": "2025-10-01",
            "end_date": "2025-10-31",
        },
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["total_sales"] == 12345.67
    assert body["top_channels"][0]["channel"] == "iFood"
