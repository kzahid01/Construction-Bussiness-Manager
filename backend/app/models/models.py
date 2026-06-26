from datetime import datetime
from typing import Optional
from sqlalchemy import (
    Column, Integer, String, Float, DateTime, ForeignKey,
    Boolean, Text, Enum as SAEnum
)
from sqlalchemy.orm import relationship
from app.database import Base
import enum


class UserRole(str, enum.Enum):
    admin = "admin"
    manager = "manager"
    worker = "worker"


class ProjectStatus(str, enum.Enum):
    planning = "planning"
    active = "active"
    on_hold = "on_hold"
    completed = "completed"
    cancelled = "cancelled"


class PurchaseStatus(str, enum.Enum):
    pending = "pending"
    received = "received"
    partial = "partial"
    cancelled = "cancelled"


class MaterialUsageType(str, enum.Enum):
    assigned = "assigned"
    returned = "returned"


# ─── Users ────────────────────────────────────────────────────────────────────

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, nullable=False, index=True)
    email = Column(String(100), unique=True, nullable=False, index=True)
    full_name = Column(String(100), nullable=False)
    hashed_password = Column(String(255), nullable=False)
    role = Column(SAEnum(UserRole), default=UserRole.worker, nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    purchases = relationship("Purchase", back_populates="created_by_user")
    material_usages = relationship("MaterialUsage", back_populates="assigned_by_user")


# ─── Warehouse & Locations ────────────────────────────────────────────────────

class Warehouse(Base):
    __tablename__ = "warehouses"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    address = Column(Text)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    locations = relationship("WarehouseLocation", back_populates="warehouse")
    inventory_items = relationship("InventoryItem", back_populates="warehouse")


class WarehouseLocation(Base):
    __tablename__ = "warehouse_locations"

    id = Column(Integer, primary_key=True, index=True)
    warehouse_id = Column(Integer, ForeignKey("warehouses.id"), nullable=False)
    rack = Column(String(20), nullable=False)
    shelf = Column(String(20), nullable=False)
    description = Column(Text)
    is_active = Column(Boolean, default=True)

    warehouse = relationship("Warehouse", back_populates="locations")
    inventory_items = relationship("InventoryItem", back_populates="location")


# ─── Inventory ────────────────────────────────────────────────────────────────

class Category(Base):
    __tablename__ = "categories"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), unique=True, nullable=False)
    description = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)

    inventory_items = relationship("InventoryItem", back_populates="category")


class InventoryItem(Base):
    __tablename__ = "inventory_items"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(150), nullable=False)
    sku = Column(String(50), unique=True, nullable=False, index=True)
    category_id = Column(Integer, ForeignKey("categories.id"), nullable=True)
    warehouse_id = Column(Integer, ForeignKey("warehouses.id"), nullable=True)
    location_id = Column(Integer, ForeignKey("warehouse_locations.id"), nullable=True)
    unit = Column(String(30), nullable=False)          # bags, kg, pcs, meters, etc.
    quantity = Column(Float, default=0.0, nullable=False)
    min_quantity = Column(Float, default=0.0)           # low-stock threshold
    unit_cost = Column(Float, default=0.0)              # latest purchase cost
    description = Column(Text)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    category = relationship("Category", back_populates="inventory_items")
    warehouse = relationship("Warehouse", back_populates="inventory_items")
    location = relationship("WarehouseLocation", back_populates="inventory_items")
    purchase_items = relationship("PurchaseItem", back_populates="inventory_item")
    material_usages = relationship("MaterialUsage", back_populates="inventory_item")


# ─── Suppliers ────────────────────────────────────────────────────────────────

class Supplier(Base):
    __tablename__ = "suppliers"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(150), nullable=False)
    contact_person = Column(String(100))
    phone = Column(String(30))
    email = Column(String(100))
    address = Column(Text)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    purchases = relationship("Purchase", back_populates="supplier")


# ─── Purchases ────────────────────────────────────────────────────────────────

class Purchase(Base):
    __tablename__ = "purchases"

    id = Column(Integer, primary_key=True, index=True)
    purchase_number = Column(String(30), unique=True, nullable=False)
    supplier_id = Column(Integer, ForeignKey("suppliers.id"), nullable=True)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    status = Column(SAEnum(PurchaseStatus), default=PurchaseStatus.pending)
    invoice_reference = Column(String(100))
    notes = Column(Text)
    total_amount = Column(Float, default=0.0)
    purchase_date = Column(DateTime, default=datetime.utcnow)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    supplier = relationship("Supplier", back_populates="purchases")
    created_by_user = relationship("User", back_populates="purchases")
    items = relationship("PurchaseItem", back_populates="purchase", cascade="all, delete-orphan")


class PurchaseItem(Base):
    __tablename__ = "purchase_items"

    id = Column(Integer, primary_key=True, index=True)
    purchase_id = Column(Integer, ForeignKey("purchases.id"), nullable=False)
    inventory_item_id = Column(Integer, ForeignKey("inventory_items.id"), nullable=False)
    quantity = Column(Float, nullable=False)
    unit_cost = Column(Float, nullable=False)
    total_cost = Column(Float, nullable=False)

    purchase = relationship("Purchase", back_populates="items")
    inventory_item = relationship("InventoryItem", back_populates="purchase_items")


# ─── Projects ─────────────────────────────────────────────────────────────────

class Project(Base):
    __tablename__ = "projects"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(200), nullable=False)
    client_name = Column(String(150))
    client_phone = Column(String(30))
    address = Column(Text)
    status = Column(SAEnum(ProjectStatus), default=ProjectStatus.planning)
    budget = Column(Float, default=0.0)               # total contract value
    estimated_cost = Column(Float, default=0.0)
    actual_material_cost = Column(Float, default=0.0)
    labour_cost = Column(Float, default=0.0)
    other_cost = Column(Float, default=0.0)
    description = Column(Text)
    start_date = Column(DateTime)
    end_date = Column(DateTime)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    material_usages = relationship("MaterialUsage", back_populates="project")

    @property
    def total_cost(self):
        return (self.actual_material_cost or 0) + (self.labour_cost or 0) + (self.other_cost or 0)

    @property
    def profit(self):
        return (self.budget or 0) - self.total_cost

    @property
    def profit_margin(self):
        if self.budget and self.budget > 0:
            return round((self.profit / self.budget) * 100, 2)
        return 0.0


# ─── Material Usage ───────────────────────────────────────────────────────────

class MaterialUsage(Base):
    __tablename__ = "material_usages"

    id = Column(Integer, primary_key=True, index=True)
    project_id = Column(Integer, ForeignKey("projects.id"), nullable=False)
    inventory_item_id = Column(Integer, ForeignKey("inventory_items.id"), nullable=False)
    assigned_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    usage_type = Column(SAEnum(MaterialUsageType), default=MaterialUsageType.assigned)
    quantity = Column(Float, nullable=False)
    unit_cost_at_time = Column(Float, default=0.0)    # cost snapshot at time of use
    total_cost = Column(Float, default=0.0)
    notes = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)

    project = relationship("Project", back_populates="material_usages")
    inventory_item = relationship("InventoryItem", back_populates="material_usages")
    assigned_by_user = relationship("User", back_populates="material_usages")
