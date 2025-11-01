from fastapi import APIRouter, Depends, Query
from fastapi.responses import StreamingResponse

from app.core.database import get_db_session
from app.repositories.sales_repository import SalesRepository
from app.services.report_service import ReportService

router = APIRouter(prefix="/reports", tags=["Reports"])


@router.get("/store-performance")
async def export_store_performance(
    store_ids: list[int] = Query(..., description="Lista de lojas para incluir no relatório"),
    start_date: str = Query(..., description="Data inicial (YYYY-MM-DD)"),
    end_date: str = Query(..., description="Data final (YYYY-MM-DD)"),
    db_session=Depends(get_db_session),
):
    """Gera um relatório CSV pronto para compartilhar com sócios e gestores."""
    repository = SalesRepository(db_session)
    service = ReportService(repository)
    csv_content, filename = await service.build_store_performance_report(
        store_ids=store_ids,
        start_date=start_date,
        end_date=end_date,
    )
    return StreamingResponse(
        iter([csv_content]),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )
