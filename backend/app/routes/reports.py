from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload
from app.database import get_db
from app.models import (
    User, InventoryItem, Project, Purchase, MaterialUsage,
    ProjectStatus, Category, Warehouse,
)
from app.schemas.schemas import (
    StockSummaryReport, StockSummaryItem,
    ProjectProfitReport, DashboardStats,
)
from app.utils.auth import get_current_user

router = APIRouter(prefix="/reports", tags=["Reports"])


@router.get("/dashboard", response_model=DashboardStats)
async def dashboard(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    total_items_r = await db.execute(
        select(func.count(InventoryItem.id)).where(InventoryItem.is_active == True)
    )
    total_items = total_items_r.scalar_one()

    low_stock_r = await db.execute(
        select(func.count(InventoryItem.id)).where(
            InventoryItem.is_active == True,
            InventoryItem.quantity <= InventoryItem.min_quantity,
        )
    )
    low_stock = low_stock_r.scalar_one()

    value_r = await db.execute(
        select(func.sum(InventoryItem.quantity * InventoryItem.unit_cost)).where(
            InventoryItem.is_active == True
        )
    )
    total_value = round(value_r.scalar_one() or 0.0, 2)

    active_r = await db.execute(
        select(func.count(Project.id)).where(Project.status == ProjectStatus.active)
    )
    active_projects = active_r.scalar_one()

    total_proj_r = await db.execute(select(func.count(Project.id)))
    total_projects = total_proj_r.scalar_one()

    total_purch_r = await db.execute(select(func.count(Purchase.id)))
    total_purchases = total_purch_r.scalar_one()

    recent_val_r = await db.execute(select(func.sum(Purchase.total_amount)))
    recent_val = round(recent_val_r.scalar_one() or 0.0, 2)

    return DashboardStats(
        total_inventory_items=total_items,
        low_stock_items=low_stock,
        total_inventory_value=total_value,
        active_projects=active_projects,
        total_projects=total_projects,
        total_purchases=total_purchases,
        recent_purchases_value=recent_val,
    )


@router.get("/stock-summary", response_model=StockSummaryReport)
async def stock_summary(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    result = await db.execute(
        select(InventoryItem)
        .options(
            selectinload(InventoryItem.category),
            selectinload(InventoryItem.warehouse),
        )
        .where(InventoryItem.is_active == True)
        .order_by(InventoryItem.name)
    )
    items = result.scalars().all()

    summary_items = []
    total_value = 0.0
    low_stock_count = 0
    out_of_stock_count = 0

    for item in items:
        item_value = round(item.quantity * item.unit_cost, 2)
        total_value += item_value
        is_low = item.quantity <= item.min_quantity
        if is_low:
            low_stock_count += 1
        if item.quantity == 0:
            out_of_stock_count += 1

        summary_items.append(StockSummaryItem(
            id=item.id,
            name=item.name,
            sku=item.sku,
            unit=item.unit,
            quantity=item.quantity,
            min_quantity=item.min_quantity,
            unit_cost=item.unit_cost,
            total_value=item_value,
            is_low_stock=is_low,
            category_name=item.category.name if item.category else None,
            warehouse_name=item.warehouse.name if item.warehouse else None,
        ))

    return StockSummaryReport(
        total_items=len(items),
        total_value=round(total_value, 2),
        low_stock_count=low_stock_count,
        out_of_stock_count=out_of_stock_count,
        items=summary_items,
    )


@router.get("/low-stock", response_model=list[StockSummaryItem])
async def low_stock_alerts(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    result = await db.execute(
        select(InventoryItem)
        .options(
            selectinload(InventoryItem.category),
            selectinload(InventoryItem.warehouse),
        )
        .where(
            InventoryItem.is_active == True,
            InventoryItem.quantity <= InventoryItem.min_quantity,
        )
        .order_by(InventoryItem.quantity)
    )
    items = result.scalars().all()
    return [
        StockSummaryItem(
            id=i.id,
            name=i.name,
            sku=i.sku,
            unit=i.unit,
            quantity=i.quantity,
            min_quantity=i.min_quantity,
            unit_cost=i.unit_cost,
            total_value=round(i.quantity * i.unit_cost, 2),
            is_low_stock=True,
            category_name=i.category.name if i.category else None,
            warehouse_name=i.warehouse.name if i.warehouse else None,
        )
        for i in items
    ]


@router.get("/project-profits", response_model=list[ProjectProfitReport])
async def project_profits(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    result = await db.execute(select(Project).order_by(Project.created_at.desc()))
    projects = result.scalars().all()
    return [
        ProjectProfitReport(
            id=p.id,
            name=p.name,
            client_name=p.client_name,
            status=p.status.value,
            budget=p.budget,
            actual_material_cost=p.actual_material_cost,
            labour_cost=p.labour_cost,
            other_cost=p.other_cost,
            total_cost=p.total_cost,
            profit=p.profit,
            profit_margin=p.profit_margin,
        )
        for p in projects
    ]


@router.get("/project/{project_id}/cost-breakdown")
async def project_cost_breakdown(
    project_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    result = await db.execute(select(Project).where(Project.id == project_id))
    p = result.scalar_one_or_none()
    if not p:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Project not found")

    usages_r = await db.execute(
        select(MaterialUsage)
        .options(selectinload(MaterialUsage.inventory_item))
        .where(MaterialUsage.project_id == project_id)
        .order_by(MaterialUsage.created_at)
    )
    usages = usages_r.scalars().all()

    material_lines = [
        {
            "date": u.created_at.isoformat(),
            "type": u.usage_type.value,
            "item_name": u.inventory_item.name if u.inventory_item else "N/A",
            "quantity": u.quantity,
            "unit_cost": u.unit_cost_at_time,
            "total": u.total_cost,
        }
        for u in usages
    ]

    return {
        "project_id": p.id,
        "project_name": p.name,
        "budget": p.budget,
        "material_cost": p.actual_material_cost,
        "labour_cost": p.labour_cost,
        "other_cost": p.other_cost,
        "total_cost": p.total_cost,
        "profit": p.profit,
        "profit_margin": p.profit_margin,
        "material_transactions": material_lines,
    }
