from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from app.database import get_db
from app.models import User, Project, InventoryItem, MaterialUsage, MaterialUsageType
from app.schemas.schemas import (
    ProjectCreate, ProjectUpdate, ProjectOut,
    MaterialUsageCreate, MaterialReturnCreate, MaterialUsageOut,
)
from app.utils.auth import get_current_user, get_admin_user

router = APIRouter(prefix="/projects", tags=["Projects"])

USAGE_LOAD = [
    selectinload(MaterialUsage.inventory_item).selectinload(InventoryItem.category),
    selectinload(MaterialUsage.inventory_item).selectinload(InventoryItem.warehouse),
    selectinload(MaterialUsage.inventory_item).selectinload(InventoryItem.location),
]


async def _get_project_or_404(project_id: int, db: AsyncSession) -> Project:
    result = await db.execute(select(Project).where(Project.id == project_id))
    p = result.scalar_one_or_none()
    if not p:
        raise HTTPException(status_code=404, detail="Project not found")
    return p


# ─── Projects CRUD ────────────────────────────────────────────────────────────

@router.post("", response_model=ProjectOut, status_code=201)
async def create_project(
    payload: ProjectCreate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    project = Project(**payload.model_dump())
    db.add(project)
    await db.flush()
    await db.refresh(project)
    out = ProjectOut.model_validate(project)
    out.total_cost = project.total_cost
    out.profit = project.profit
    out.profit_margin = project.profit_margin
    return out


@router.get("", response_model=list[ProjectOut])
async def list_projects(
    status: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    q = select(Project)
    if status:
        q = q.where(Project.status == status)
    if search:
        q = q.where(Project.name.ilike(f"%{search}%") | Project.client_name.ilike(f"%{search}%"))
    q = q.order_by(Project.created_at.desc()).offset(skip).limit(limit)
    result = await db.execute(q)
    projects = result.scalars().all()
    out = []
    for p in projects:
        o = ProjectOut.model_validate(p)
        o.total_cost = p.total_cost
        o.profit = p.profit
        o.profit_margin = p.profit_margin
        out.append(o)
    return out


@router.get("/{project_id}", response_model=ProjectOut)
async def get_project(
    project_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    p = await _get_project_or_404(project_id, db)
    o = ProjectOut.model_validate(p)
    o.total_cost = p.total_cost
    o.profit = p.profit
    o.profit_margin = p.profit_margin
    return o


@router.put("/{project_id}", response_model=ProjectOut)
async def update_project(
    project_id: int,
    payload: ProjectUpdate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    p = await _get_project_or_404(project_id, db)
    for field, value in payload.model_dump(exclude_none=True).items():
        setattr(p, field, value)
    await db.flush()
    await db.refresh(p)
    o = ProjectOut.model_validate(p)
    o.total_cost = p.total_cost
    o.profit = p.profit
    o.profit_margin = p.profit_margin
    return o


@router.delete("/{project_id}", status_code=204)
async def delete_project(
    project_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_admin_user),
):
    p = await _get_project_or_404(project_id, db)
    await db.delete(p)


# ─── Material Usage ───────────────────────────────────────────────────────────

@router.post("/{project_id}/assign-material", response_model=MaterialUsageOut, status_code=201)
async def assign_material(
    project_id: int,
    payload: MaterialUsageCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Assign (consume) materials from inventory to a project."""
    if payload.project_id != project_id:
        raise HTTPException(status_code=400, detail="project_id mismatch in body vs URL")

    project = await _get_project_or_404(project_id, db)

    result = await db.execute(
        select(InventoryItem).where(InventoryItem.id == payload.inventory_item_id)
    )
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=404, detail="Inventory item not found")
    if item.quantity < payload.quantity:
        raise HTTPException(
            status_code=400,
            detail=f"Insufficient stock. Available: {item.quantity} {item.unit}",
        )

    total_cost = round(payload.quantity * item.unit_cost, 2)

    usage = MaterialUsage(
        project_id=project_id,
        inventory_item_id=payload.inventory_item_id,
        assigned_by=current_user.id,
        usage_type=MaterialUsageType.assigned,
        quantity=payload.quantity,
        unit_cost_at_time=item.unit_cost,
        total_cost=total_cost,
        notes=payload.notes,
    )
    db.add(usage)

    # deduct stock
    item.quantity = round(item.quantity - payload.quantity, 4)

    # update project material cost
    project.actual_material_cost = round(
        (project.actual_material_cost or 0) + total_cost, 2
    )

    await db.flush()
    await db.refresh(usage)

    result2 = await db.execute(
        select(MaterialUsage).options(*USAGE_LOAD).where(MaterialUsage.id == usage.id)
    )
    usage = result2.scalar_one()
    return MaterialUsageOut.model_validate(usage)


@router.post("/{project_id}/return-material", response_model=MaterialUsageOut, status_code=201)
async def return_material(
    project_id: int,
    payload: MaterialReturnCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Return unused materials from project back to inventory."""
    if payload.project_id != project_id:
        raise HTTPException(status_code=400, detail="project_id mismatch in body vs URL")

    project = await _get_project_or_404(project_id, db)

    result = await db.execute(
        select(InventoryItem).where(InventoryItem.id == payload.inventory_item_id)
    )
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=404, detail="Inventory item not found")

    total_cost = round(payload.quantity * item.unit_cost, 2)

    usage = MaterialUsage(
        project_id=project_id,
        inventory_item_id=payload.inventory_item_id,
        assigned_by=current_user.id,
        usage_type=MaterialUsageType.returned,
        quantity=payload.quantity,
        unit_cost_at_time=item.unit_cost,
        total_cost=total_cost,
        notes=payload.notes,
    )
    db.add(usage)

    # return stock
    item.quantity = round(item.quantity + payload.quantity, 4)

    # subtract from project material cost
    project.actual_material_cost = round(
        max(0.0, (project.actual_material_cost or 0) - total_cost), 2
    )

    await db.flush()
    await db.refresh(usage)

    result2 = await db.execute(
        select(MaterialUsage).options(*USAGE_LOAD).where(MaterialUsage.id == usage.id)
    )
    usage = result2.scalar_one()
    return MaterialUsageOut.model_validate(usage)


@router.get("/{project_id}/materials", response_model=list[MaterialUsageOut])
async def get_project_materials(
    project_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    await _get_project_or_404(project_id, db)
    result = await db.execute(
        select(MaterialUsage)
        .options(*USAGE_LOAD)
        .where(MaterialUsage.project_id == project_id)
        .order_by(MaterialUsage.created_at.desc())
    )
    return [MaterialUsageOut.model_validate(u) for u in result.scalars().all()]
