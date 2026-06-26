from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, EmailStr, Field, ConfigDict
from app.models.models import UserRole, ProjectStatus, PurchaseStatus, MaterialUsageType


# ─── Token ────────────────────────────────────────────────────────────────────

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: "UserOut"


class TokenData(BaseModel):
    user_id: Optional[int] = None


# ─── User ─────────────────────────────────────────────────────────────────────

class UserCreate(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    email: EmailStr
    full_name: str = Field(..., min_length=1, max_length=100)
    password: str = Field(..., min_length=6)
    role: UserRole = UserRole.worker


class UserUpdate(BaseModel):
    email: Optional[EmailStr] = None
    full_name: Optional[str] = None
    role: Optional[UserRole] = None
    is_active: Optional[bool] = None


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    username: str
    email: str
    full_name: str
    role: UserRole
    is_active: bool
    created_at: datetime


class LoginRequest(BaseModel):
    username: str
    password: str


# ─── Warehouse ────────────────────────────────────────────────────────────────

class WarehouseCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    address: Optional[str] = None


class WarehouseOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    name: str
    address: Optional[str]
    is_active: bool
    created_at: datetime


class WarehouseLocationCreate(BaseModel):
    warehouse_id: int
    rack: str = Field(..., max_length=20)
    shelf: str = Field(..., max_length=20)
    description: Optional[str] = None


class WarehouseLocationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    warehouse_id: int
    rack: str
    shelf: str
    description: Optional[str]
    is_active: bool


# ─── Category ─────────────────────────────────────────────────────────────────

class CategoryCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = None


class CategoryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    name: str
    description: Optional[str]
    created_at: datetime


# ─── Inventory ────────────────────────────────────────────────────────────────

class InventoryItemCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=150)
    sku: str = Field(..., min_length=1, max_length=50)
    category_id: Optional[int] = None
    warehouse_id: Optional[int] = None
    location_id: Optional[int] = None
    unit: str = Field(..., max_length=30)
    quantity: float = Field(default=0.0, ge=0)
    min_quantity: float = Field(default=0.0, ge=0)
    unit_cost: float = Field(default=0.0, ge=0)
    description: Optional[str] = None


class InventoryItemUpdate(BaseModel):
    name: Optional[str] = None
    category_id: Optional[int] = None
    warehouse_id: Optional[int] = None
    location_id: Optional[int] = None
    unit: Optional[str] = None
    quantity: Optional[float] = Field(default=None, ge=0)
    min_quantity: Optional[float] = Field(default=None, ge=0)
    unit_cost: Optional[float] = Field(default=None, ge=0)
    description: Optional[str] = None
    is_active: Optional[bool] = None


class InventoryItemOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    name: str
    sku: str
    category_id: Optional[int]
    warehouse_id: Optional[int]
    location_id: Optional[int]
    unit: str
    quantity: float
    min_quantity: float
    unit_cost: float
    description: Optional[str]
    is_active: bool
    created_at: datetime
    updated_at: datetime
    category: Optional[CategoryOut] = None
    warehouse: Optional[WarehouseOut] = None
    location: Optional[WarehouseLocationOut] = None

    @property
    def is_low_stock(self) -> bool:
        return self.quantity <= self.min_quantity


class InventoryAdjust(BaseModel):
    quantity_change: float
    notes: Optional[str] = None


# ─── Supplier ─────────────────────────────────────────────────────────────────

class SupplierCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=150)
    contact_person: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    address: Optional[str] = None


class SupplierUpdate(BaseModel):
    name: Optional[str] = None
    contact_person: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    address: Optional[str] = None
    is_active: Optional[bool] = None


class SupplierOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    name: str
    contact_person: Optional[str]
    phone: Optional[str]
    email: Optional[str]
    address: Optional[str]
    is_active: bool
    created_at: datetime


# ─── Purchase ─────────────────────────────────────────────────────────────────

class PurchaseItemCreate(BaseModel):
    inventory_item_id: int
    quantity: float = Field(..., gt=0)
    unit_cost: float = Field(..., ge=0)


class PurchaseItemOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    inventory_item_id: int
    quantity: float
    unit_cost: float
    total_cost: float
    inventory_item: Optional[InventoryItemOut] = None


class PurchaseCreate(BaseModel):
    supplier_id: Optional[int] = None
    invoice_reference: Optional[str] = None
    notes: Optional[str] = None
    purchase_date: Optional[datetime] = None
    items: List[PurchaseItemCreate] = Field(..., min_length=1)


class PurchaseUpdate(BaseModel):
    supplier_id: Optional[int] = None
    status: Optional[PurchaseStatus] = None
    invoice_reference: Optional[str] = None
    notes: Optional[str] = None


class PurchaseOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    purchase_number: str
    supplier_id: Optional[int]
    created_by: int
    status: PurchaseStatus
    invoice_reference: Optional[str]
    notes: Optional[str]
    total_amount: float
    purchase_date: datetime
    created_at: datetime
    supplier: Optional[SupplierOut] = None
    items: List[PurchaseItemOut] = []


# ─── Project ──────────────────────────────────────────────────────────────────

class ProjectCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    client_name: Optional[str] = None
    client_phone: Optional[str] = None
    address: Optional[str] = None
    budget: float = Field(default=0.0, ge=0)
    estimated_cost: float = Field(default=0.0, ge=0)
    labour_cost: float = Field(default=0.0, ge=0)
    other_cost: float = Field(default=0.0, ge=0)
    description: Optional[str] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None


class ProjectUpdate(BaseModel):
    name: Optional[str] = None
    client_name: Optional[str] = None
    client_phone: Optional[str] = None
    address: Optional[str] = None
    status: Optional[ProjectStatus] = None
    budget: Optional[float] = Field(default=None, ge=0)
    estimated_cost: Optional[float] = Field(default=None, ge=0)
    labour_cost: Optional[float] = Field(default=None, ge=0)
    other_cost: Optional[float] = Field(default=None, ge=0)
    description: Optional[str] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None


class ProjectOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    name: str
    client_name: Optional[str]
    client_phone: Optional[str]
    address: Optional[str]
    status: ProjectStatus
    budget: float
    estimated_cost: float
    actual_material_cost: float
    labour_cost: float
    other_cost: float
    description: Optional[str]
    start_date: Optional[datetime]
    end_date: Optional[datetime]
    created_at: datetime
    total_cost: float = 0.0
    profit: float = 0.0
    profit_margin: float = 0.0

    @classmethod
    def model_validate(cls, obj, *args, **kwargs):
        instance = super().model_validate(obj, *args, **kwargs)
        if hasattr(obj, 'total_cost'):
            instance.total_cost = obj.total_cost
        if hasattr(obj, 'profit'):
            instance.profit = obj.profit
        if hasattr(obj, 'profit_margin'):
            instance.profit_margin = obj.profit_margin
        return instance


# ─── Material Usage ───────────────────────────────────────────────────────────

class MaterialUsageCreate(BaseModel):
    project_id: int
    inventory_item_id: int
    quantity: float = Field(..., gt=0)
    notes: Optional[str] = None


class MaterialReturnCreate(BaseModel):
    project_id: int
    inventory_item_id: int
    quantity: float = Field(..., gt=0)
    notes: Optional[str] = None


class MaterialUsageOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    project_id: int
    inventory_item_id: int
    assigned_by: int
    usage_type: MaterialUsageType
    quantity: float
    unit_cost_at_time: float
    total_cost: float
    notes: Optional[str]
    created_at: datetime
    inventory_item: Optional[InventoryItemOut] = None


# ─── Reports ──────────────────────────────────────────────────────────────────

class StockSummaryItem(BaseModel):
    id: int
    name: str
    sku: str
    unit: str
    quantity: float
    min_quantity: float
    unit_cost: float
    total_value: float
    is_low_stock: bool
    category_name: Optional[str]
    warehouse_name: Optional[str]


class StockSummaryReport(BaseModel):
    total_items: int
    total_value: float
    low_stock_count: int
    out_of_stock_count: int
    items: List[StockSummaryItem]


class ProjectProfitReport(BaseModel):
    id: int
    name: str
    client_name: Optional[str]
    status: str
    budget: float
    actual_material_cost: float
    labour_cost: float
    other_cost: float
    total_cost: float
    profit: float
    profit_margin: float


class DashboardStats(BaseModel):
    total_inventory_items: int
    low_stock_items: int
    total_inventory_value: float
    active_projects: int
    total_projects: int
    total_purchases: int
    recent_purchases_value: float
