import re
from datetime import datetime
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload
from app.database import get_db
from app.models import User, Purchase, PurchaseItem, Supplier, InventoryItem, PurchaseStatus
from app.schemas.schemas import (
    PurchaseCreate, PurchaseUpdate, PurchaseOut,
    SupplierCreate, SupplierUpdate, SupplierOut,
)
from app.utils.auth import get_current_user, get_admin_user

router = APIRouter(tags=["Purchases & Suppliers"])

PURCHASE_LOAD = [
    selectinload(Purchase.supplier),
    selectinload(Purchase.items)
    .selectinload(PurchaseItem.inventory_item)
    .selectinload(InventoryItem.category),
    selectinload(Purchase.items)
    .selectinload(PurchaseItem.inventory_item)
    .selectinload(InventoryItem.warehouse),
    selectinload(Purchase.items)
    .selectinload(PurchaseItem.inventory_item)
    .selectinload(InventoryItem.location),
]


async def _gen_purchase_number(db: AsyncSession) -> str:
    result = await db.execute(select(func.count(Purchase.id)))
    count = result.scalar_one() + 1
    return f"PO-{datetime.utcnow().strftime('%Y%m')}-{count:04d}"


async def _get_purchase_or_404(purchase_id: int, db: AsyncSession) -> Purchase:
    result = await db.execute(
        select(Purchase).options(*PURCHASE_LOAD).where(Purchase.id == purchase_id)
    )
    p = result.scalar_one_or_none()
    if not p:
        raise HTTPException(status_code=404, detail="Purchase not found")
    return p


# ─── Suppliers ────────────────────────────────────────────────────────────────

@router.post("/suppliers", response_model=SupplierOut, status_code=201, tags=["Purchases & Suppliers"])
async def create_supplier(
    payload: SupplierCreate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    supplier = Supplier(**payload.model_dump())
    db.add(supplier)
    await db.flush()
    await db.refresh(supplier)
    return SupplierOut.model_validate(supplier)


@router.get("/suppliers", response_model=list[SupplierOut], tags=["Purchases & Suppliers"])
async def list_suppliers(
    search: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    q = select(Supplier).where(Supplier.is_active == True)
    if search:
        q = q.where(Supplier.name.ilike(f"%{search}%"))
    result = await db.execute(q.order_by(Supplier.name))
    return [SupplierOut.model_validate(s) for s in result.scalars().all()]


@router.get("/suppliers/{supplier_id}", response_model=SupplierOut, tags=["Purchases & Suppliers"])
async def get_supplier(
    supplier_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    result = await db.execute(select(Supplier).where(Supplier.id == supplier_id))
    s = result.scalar_one_or_none()
    if not s:
        raise HTTPException(status_code=404, detail="Supplier not found")
    return SupplierOut.model_validate(s)


@router.put("/suppliers/{supplier_id}", response_model=SupplierOut, tags=["Purchases & Suppliers"])
async def update_supplier(
    supplier_id: int,
    payload: SupplierUpdate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    result = await db.execute(select(Supplier).where(Supplier.id == supplier_id))
    s = result.scalar_one_or_none()
    if not s:
        raise HTTPException(status_code=404, detail="Supplier not found")
    for k, v in payload.model_dump(exclude_none=True).items():
        setattr(s, k, v)
    await db.flush()
    await db.refresh(s)
    return SupplierOut.model_validate(s)


@router.delete("/suppliers/{supplier_id}", status_code=204, tags=["Purchases & Suppliers"])
async def delete_supplier(
    supplier_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user),
):
    result = await db.execute(select(Supplier).where(Supplier.id == supplier_id))
    s = result.scalar_one_or_none()
    if not s:
        raise HTTPException(status_code=404, detail="Supplier not found")
    s.is_active = False
    await db.flush()


# ─── Purchases ────────────────────────────────────────────────────────────────

@router.post("/purchases", response_model=PurchaseOut, status_code=201, tags=["Purchases & Suppliers"])
async def create_purchase(
    payload: PurchaseCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    purchase_number = await _gen_purchase_number(db)
    total = 0.0

    purchase = Purchase(
        purchase_number=purchase_number,
        supplier_id=payload.supplier_id,
        created_by=current_user.id,
        invoice_reference=payload.invoice_reference,
        notes=payload.notes,
        purchase_date=payload.purchase_date or datetime.utcnow(),
        status=PurchaseStatus.pending,
    )
    db.add(purchase)
    await db.flush()

    for line in payload.items:
        # validate item exists
        result = await db.execute(
            select(InventoryItem).where(InventoryItem.id == line.inventory_item_id)
        )
        inv_item = result.scalar_one_or_none()
        if not inv_item:
            raise HTTPException(
                status_code=404,
                detail=f"Inventory item id={line.inventory_item_id} not found",
            )
        line_total = round(line.quantity * line.unit_cost, 2)
        total += line_total

        pi = PurchaseItem(
            purchase_id=purchase.id,
            inventory_item_id=line.inventory_item_id,
            quantity=line.quantity,
            unit_cost=line.unit_cost,
            total_cost=line_total,
        )
        db.add(pi)

        # immediately update stock and unit cost
        inv_item.quantity = round(inv_item.quantity + line.quantity, 4)
        inv_item.unit_cost = line.unit_cost  # update to latest purchase price

    purchase.total_amount = round(total, 2)
    purchase.status = PurchaseStatus.received
    await db.flush()

    purchase = await _get_purchase_or_404(purchase.id, db)
    return PurchaseOut.model_validate(purchase)


@router.get("/purchases", response_model=list[PurchaseOut], tags=["Purchases & Suppliers"])
async def list_purchases(
    supplier_id: Optional[int] = Query(None),
    status: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    q = select(Purchase).options(*PURCHASE_LOAD)
    if supplier_id:
        q = q.where(Purchase.supplier_id == supplier_id)
    if status:
        q = q.where(Purchase.status == status)
    q = q.order_by(Purchase.created_at.desc()).offset(skip).limit(limit)
    result = await db.execute(q)
    return [PurchaseOut.model_validate(p) for p in result.scalars().all()]


@router.get("/purchases/{purchase_id}", response_model=PurchaseOut, tags=["Purchases & Suppliers"])
async def get_purchase(
    purchase_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    p = await _get_purchase_or_404(purchase_id, db)
    return PurchaseOut.model_validate(p)


@router.put("/purchases/{purchase_id}", response_model=PurchaseOut, tags=["Purchases & Suppliers"])
async def update_purchase(
    purchase_id: int,
    payload: PurchaseUpdate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user),
):
    result = await db.execute(select(Purchase).where(Purchase.id == purchase_id))
    p = result.scalar_one_or_none()
    if not p:
        raise HTTPException(status_code=404, detail="Purchase not found")
    for k, v in payload.model_dump(exclude_none=True).items():
        setattr(p, k, v)
    await db.flush()
    p = await _get_purchase_or_404(purchase_id, db)
    return PurchaseOut.model_validate(p)


@router.delete("/purchases/{purchase_id}", status_code=204, tags=["Purchases & Suppliers"])
async def delete_purchase(
    purchase_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user),
):
    p = await _get_purchase_or_404(purchase_id, db)
    if p.status == PurchaseStatus.received:
        raise HTTPException(
            status_code=400,
            detail="Cannot delete a received purchase. Cancel it instead.",
        )
    await db.delete(p)
