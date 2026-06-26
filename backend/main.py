from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.config import settings
from app.database import init_db
from app.routes import (
    auth_router, inventory_router, projects_router,
    purchases_router, reports_router,
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description=(
        "REST API for Construction & Real Estate Management — "
        "Inventory, Projects, Purchases, Suppliers, and Reporting."
    ),
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],          # tighten in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

API_PREFIX = "/api/v1"
app.include_router(auth_router,      prefix=API_PREFIX)
app.include_router(inventory_router, prefix=API_PREFIX)
app.include_router(projects_router,  prefix=API_PREFIX)
app.include_router(purchases_router, prefix=API_PREFIX)
app.include_router(reports_router,   prefix=API_PREFIX)


@app.get("/", tags=["Health"])
async def root():
    return {"status": "ok", "app": settings.APP_NAME, "version": settings.APP_VERSION}


@app.get("/health", tags=["Health"])
async def health():
    return {"status": "healthy"}
