from app.routes.auth import router as auth_router
from app.routes.inventory import router as inventory_router
from app.routes.projects import router as projects_router
from app.routes.purchases import router as purchases_router
from app.routes.reports import router as reports_router

__all__ = [
    "auth_router",
    "inventory_router",
    "projects_router",
    "purchases_router",
    "reports_router",
]
