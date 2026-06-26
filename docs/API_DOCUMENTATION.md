# Construction & Real Estate Management System — API Documentation
Version: 1.0.0 | Base URL: `http://localhost:8000/api/v1`

---

## Authentication
All endpoints (except `/auth/login`) require a Bearer token in the header:
```
Authorization: Bearer <token>
```

---

## 1. Authentication

### POST /auth/login
Login and receive JWT token.
```json
// Request
{ "username": "admin", "password": "Admin@123" }

// Response 200
{
  "access_token": "eyJ...",
  "token_type": "bearer",
  "user": { "id": 1, "username": "admin", "role": "admin", ... }
}
```

### POST /auth/register *(admin/manager only)*
Create a new user account.
```json
// Request
{ "username": "newuser", "email": "u@x.com", "full_name": "Name", "password": "Pass@123", "role": "worker" }
```

### GET /auth/me
Get current user profile.

### PUT /auth/me
Update own profile (cannot change own role).

### GET /auth/users *(admin/manager only)*
List all users.

### PUT /auth/users/{id} *(admin/manager only)*
Update any user (including role and active status).

---

## 2. Inventory

### Categories
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | /inventory/categories | Any | List all categories |
| POST | /inventory/categories | Admin | Create category |
| DELETE | /inventory/categories/{id} | Admin | Delete category |

### Warehouses & Locations
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | /inventory/warehouses | Any | List warehouses |
| POST | /inventory/warehouses | Admin | Create warehouse |
| PUT | /inventory/warehouses/{id} | Admin | Update warehouse |
| GET | /inventory/locations | Any | List locations (filter: ?warehouse_id=) |
| POST | /inventory/locations | Admin | Create rack/shelf location |

### Inventory Items
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | /inventory/items | Any | List items (filters: search, category_id, warehouse_id, low_stock_only) |
| POST | /inventory/items | Any | Create item |
| GET | /inventory/items/{id} | Any | Get single item |
| PUT | /inventory/items/{id} | Any | Update item |
| DELETE | /inventory/items/{id} | Admin | Soft-delete item |
| POST | /inventory/items/{id}/adjust | Any | Adjust stock quantity |

**Query filters for GET /inventory/items:**
- `search=cement` — name/SKU search
- `category_id=1` — filter by category
- `warehouse_id=1` — filter by warehouse
- `low_stock_only=true` — only items at/below minimum
- `skip=0&limit=100` — pagination

**Inventory Item Object:**
```json
{
  "id": 1,
  "name": "OPC Cement 50kg Bag",
  "sku": "CEM-OPC-50",
  "unit": "bags",
  "quantity": 350.0,
  "min_quantity": 50.0,
  "unit_cost": 650.0,
  "category": { "id": 1, "name": "Cement & Concrete" },
  "warehouse": { "id": 1, "name": "Main Warehouse" },
  "location": { "id": 1, "rack": "R1", "shelf": "S1" }
}
```

**Stock Adjust Request:**
```json
{ "quantity_change": -50.0, "notes": "Manual correction" }
```

---

## 3. Projects

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | /projects | Any | List projects (filters: status, search) |
| POST | /projects | Any | Create project |
| GET | /projects/{id} | Any | Get project with profit calculation |
| PUT | /projects/{id} | Any | Update project |
| DELETE | /projects/{id} | Admin | Delete project |
| POST | /projects/{id}/assign-material | Any | Assign material (deducts stock) |
| POST | /projects/{id}/return-material | Any | Return material (restores stock) |
| GET | /projects/{id}/materials | Any | Get all material transactions |

**Project Object:**
```json
{
  "id": 1,
  "name": "DHA Villa Construction",
  "client_name": "Mr. Salman Akhtar",
  "status": "active",
  "budget": 12000000.0,
  "actual_material_cost": 157600.0,
  "labour_cost": 2800000.0,
  "other_cost": 350000.0,
  "total_cost": 3307600.0,
  "profit": 8692400.0,
  "profit_margin": 72.44
}
```

**Assign Material Request:**
```json
{
  "project_id": 1,
  "inventory_item_id": 1,
  "quantity": 50.0,
  "notes": "Foundation slab"
}
```
> Stock is automatically deducted. Returns 400 if insufficient stock.

**Return Material Request:**
```json
{
  "project_id": 1,
  "inventory_item_id": 1,
  "quantity": 10.0,
  "notes": "Surplus returned"
}
```
> Stock is automatically restored. Project material cost is reduced.

---

## 4. Suppliers

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | /suppliers | Any | List suppliers (filter: search) |
| POST | /suppliers | Any | Create supplier |
| GET | /suppliers/{id} | Any | Get supplier |
| PUT | /suppliers/{id} | Any | Update supplier |
| DELETE | /suppliers/{id} | Admin | Soft-delete supplier |

---

## 5. Purchases

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | /purchases | Any | List purchases (filters: supplier_id, status) |
| POST | /purchases | Any | Create purchase (auto-updates stock & unit_cost) |
| GET | /purchases/{id} | Any | Get purchase detail |
| PUT | /purchases/{id} | Admin | Update purchase metadata |
| DELETE | /purchases/{id} | Admin | Delete (blocked if status=received) |

**Create Purchase Request:**
```json
{
  "supplier_id": 1,
  "invoice_reference": "INV-2025-001",
  "purchase_date": "2025-01-15T00:00:00",
  "notes": "Monthly cement order",
  "items": [
    { "inventory_item_id": 1, "quantity": 200, "unit_cost": 640.0 },
    { "inventory_item_id": 2, "quantity": 400, "unit_cost": 62.0 }
  ]
}
```
> Stock quantities and unit costs are automatically updated on creation.
> Purchase status is set to `received` immediately.

---

## 6. Reports

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /reports/dashboard | KPI summary stats |
| GET | /reports/stock-summary | Full stock report with values |
| GET | /reports/low-stock | Items at/below minimum quantity |
| GET | /reports/project-profits | Profit/loss per project |
| GET | /reports/project/{id}/cost-breakdown | Detailed cost + material log |

**Dashboard Response:**
```json
{
  "total_inventory_items": 22,
  "low_stock_items": 3,
  "total_inventory_value": 8542000.0,
  "active_projects": 2,
  "total_projects": 3,
  "total_purchases": 2,
  "recent_purchases_value": 370800.0
}
```

**Stock Summary Response:**
```json
{
  "total_items": 22,
  "total_value": 8542000.0,
  "low_stock_count": 3,
  "out_of_stock_count": 0,
  "items": [...]
}
```

---

## Error Responses
All errors return:
```json
{ "detail": "Human-readable error message" }
```

| Code | Meaning |
|------|---------|
| 400 | Bad request (validation, insufficient stock, duplicate SKU) |
| 401 | Not authenticated / invalid/expired token |
| 403 | Insufficient role permissions |
| 404 | Resource not found |
| 422 | Request body schema validation failure |
| 500 | Internal server error |

---

## Interactive Docs
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`
