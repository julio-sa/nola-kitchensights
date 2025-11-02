# tests/test_widgets_top_products_endpoint.py
import pytest
from httpx import AsyncClient
from app.main import app  # ajuste o caminho se seu FastAPI estiver em outro arquivo

@pytest.mark.asyncio
async def test_widgets_top_products_endpoint():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        resp = await ac.get(
            "/api/v1/widgets/top-products",
            params={
                "store_id": 1,
                "channel": "iFood",
                "day_of_week": 5,
                "hour_start": 18,
                "hour_end": 23,
            },
        )

    assert resp.status_code == 200
    data = resp.json()
    assert "products" in data
    assert isinstance(data["products"], list)
