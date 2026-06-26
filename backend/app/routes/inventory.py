from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload
from app.database import get_db
from app.models import User, InventoryItem, Category, Warehouse, WarehouseLocation
from app.schemas.schemas import (
    InventoryItemCreate, InventoryItemUpdate, InventoryItemOut, InventoryAdjust,
    CategoryCreate, CategoryOut,
    WarehouseCreate, WarehouseOut,
    WarehouseLocationCreate, WarehouseLocationOut,
)
from app.utils.auth import get_current_user, get_admin_user

router = APIRouter(prefix="/inventory", tags=["Inventory"])

# ─── Helper ───────────────────────────────────────────────────────────────────

ITEM_LOAD = [
    selectinload(InventoryItem.category),
    selectinload(InventoryItem.warehouse),
    selectinload(InventoryItem.location),
]


async def _get_item_or_404(item_id: int, db: AsyncSession) -> InventoryItem:
    result = await db.execute(
        select(InventoryItem)
        .options(*ITEM_LOAD)
        .where(InventoryItem.id == item_id)
    )
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=404, detail="Inventory item not found")
    return item


# ─── Categories ───────────────────────────────────────────────────────────────

@router.post("/categories", response_model=CategoryOut, status_code=201)
async def create_category(
    payload: CategoryCreate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user),
):
    dup = await db.execute(select(Category).where(Category.name == payload.name))
    if dup.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Category already exists")
    cat = Category(**payload.model_dump())
    db.add(cat)
    await db.flush()
    await db.refresh(cat)
    return CategoryOut.model_validate(cat)


@router.get("/categories", response_model=list[CategoryOut])
async def list_categories(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    result = await db.execute(select(Category).order_by(Category.name))
    return [CategoryOut.model_validate(c) for c in result.scalars().all()]


@router.delete("/categories/{cat_id}", status_code=204)
async def delete_category(
    cat_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user),
):
    result = await db.execute(select(Category).where(Category.id == cat_id))
    cat = result.scalar_one_or_none()
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    await db.delete(cat)


# ─── Warehouses ───────────────────────────────────────────────────────────────

@router.post("/warehouses", response_model=WarehouseOut, status_code=201)
async def create_warehouse(
    payload: WarehouseCreate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user),
):
    wh = Warehouse(**payload.model_dump())
    db.add(wh)
    await db.flush()
    await db.refresh(wh)
    return WarehouseOut.model_validate(wh)


@router.get("/warehouses", response_model=list[WarehouseOut])
async def list_warehouses(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    result = await db.execute(select(Warehouse).where(Warehouse.is_active == True).order_by(Warehouse.name))
    return [WarehouseOut.model_validate(w) for w in result.scalars().all()]


@router.put("/warehouses/{wh_id}", response_model=WarehouseOut)
async def update_warehouse(
    wh_id: int,
    payload: WarehouseCreate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user),
):
    result = await db.execute(select(Warehouse).where(Warehouse.id == wh_id))
    wh = result.scalar_one_or_none()
    if not wh:
        raise HTTPException(status_code=404, detail="Warehouse not found")
    for k, v in payload.model_dump(exclude_none=True).items():
        setattr(wh, k, v)
    await db.flush()
    await db.refresh(wh)
    return WarehouseOut.model_validate(wh)


# ─── Warehouse Locations ──────────────────────────────────────────────────────

@router.post("/locations", response_model=WarehouseLocationOut, status_code=201)
async def create_location(
    payload: WarehouseLocationCreate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user),
):
    loc = WarehouseLocation(**payload.model_dump())
    db.add(loc)
    await db.flush()
    await db.refresh(loc)
    return WarehouseLocationOut.model_validate(loc)


@router.get("/locations", response_model=list[WarehouseLocationOut])
async def list_locations(
    warehouse_id: Optional[int] = Query(None),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    q = select(WarehouseLocation).where(WarehouseLocation.is_active == True)
    if warehouse_id:
        q = q.where(WarehouseLocation.warehouse_id == warehouse_id)
    result = await db.execute(q.order_by(WarehouseLocation.rack, WarehouseLocation.shelf))
    return [WarehouseLocationOut.model_validate(l) for l in result.scalars().all()]


# ─── Inventory Items ──────────────────────────────────────────────────────────

@router.post("/items", response_model=InventoryItemOut, status_code=201)
async def create_item(
    payload: InventoryItemCreate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    dup = await db.execute(select(InventoryItem).where(InventoryItem.sku == payload.sku))
    if dup.scalar_one_or_none():
        raise HTTPException(status_code=400, detail=f"SKU '{payload.sku}' already exists")
    item = InventoryItem(**payload.model_dump())
    db.add(item)
    await db.flush()
    # reload with relationships
    item = await _get_item_or_404(item.id, db)
    return InventoryItemOut.model_validate(item)


@router.get("/items", response_model=list[InventoryItemOut])
async def list_items(
    category_id: Optional[int] = Query(None),
    warehouse_id: Optional[int] = Query(None),
    low_stock_only: bool = Query(False),
    search: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    q = select(InventoryItem).options(*ITEM_LOAD).where(InventoryItem.is_active == True)
    if category_id:
        q = q.where(InventoryItem.category_id == category_id)
    if warehouse_id:
        q = q.where(InventoryItem.warehouse_id == warehouse_id)
    if search:
        q = q.where(
            InventoryItem.name.ilike(f"%{search}%") | InventoryItem.sku.ilike(f"%{search}%")
        )
    if low_stock_only:
        q = q.where(InventoryItem.quantity <= InventoryItem.min_quantity)
    q = q.order_by(InventoryItem.name).offset(skip).limit(limit)
    result = await db.execute(q)
    items = result.scalars().all()
    out = []
    for item in items:
        o = InventoryItemOut.model_validate(item)
        out.append(o)
    return out


@router.get("/items/{item_id}", response_model=InventoryItemOut)
async def get_item(
    item_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    item = await _get_item_or_404(item_id, db)
    return InventoryItemOut.model_validate(item)


@router.put("/items/{item_id}", response_model=InventoryItemOut)
async def update_item(
    item_id: int,
    payload: InventoryItemUpdate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    item = await _get_item_or_404(item_id, db)
    for field, value in payload.model_dump(exclude_none=True).items():
        setattr(item, field, value)
    await db.flush()
    item = await _get_item_or_404(item_id, db)
    return InventoryItemOut.model_validate(item)


@router.delete("/items/{item_id}", status_code=204)
async def delete_item(
    item_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user),
):
    item = await _get_item_or_404(item_id, db)
    item.is_active = False
    await db.flush()


@router.post("/items/{item_id}/adjust", response_model=InventoryItemOut)
async def adjust_stock(
    item_id: int,
    payload: InventoryAdjust,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    """Manually adjust stock quantity (positive = add, negative = deduct)."""
    item = await _get_item_or_404(item_id, db)
    new_qty = item.quantity + payload.quantity_change
    if new_qty < 0:
        raise HTTPException(status_code=400, detail="Adjustment would result in negative stock")
    item.quantity = new_qty
    await db.flush()
    item = await _get_item_or_404(item_id, db)
    return InventoryItemOut.model_validate(item)
