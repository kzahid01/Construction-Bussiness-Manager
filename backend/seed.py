"""
Seed script — populates the database with realistic sample data.
Run:  python seed.py
"""
import asyncio
from datetime import datetime, timedelta
from app.database import init_db, AsyncSessionLocal
from app.models.models import (
    User, UserRole,
    Warehouse, WarehouseLocation,
    Category, InventoryItem,
    Supplier,
    Purchase, PurchaseItem, PurchaseStatus,
    Project, ProjectStatus,
    MaterialUsage, MaterialUsageType,
)
from app.utils.auth import get_password_hash


async def seed():
    await init_db()
    async with AsyncSessionLocal() as db:
        # ── Users ─────────────────────────────────────────────────────────────
        admin = User(
            username="admin",
            email="admin@construction.com",
            full_name="System Administrator",
            hashed_password=get_password_hash("Admin@123"),
            role=UserRole.admin,
        )
        manager = User(
            username="manager",
            email="manager@construction.com",
            full_name="Ahmed Khan",
            hashed_password=get_password_hash("Manager@123"),
            role=UserRole.manager,
        )
        worker = User(
            username="worker",
            email="worker@construction.com",
            full_name="Ali Hassan",
            hashed_password=get_password_hash("Worker@123"),
            role=UserRole.worker,
        )
        db.add_all([admin, manager, worker])
        await db.flush()

        # ── Warehouses ────────────────────────────────────────────────────────
        wh_main = Warehouse(name="Main Warehouse", address="Industrial Zone, Block A, Rawalpindi")
        wh_site = Warehouse(name="Site Storage - DHA Phase 6", address="DHA Phase 6, Lahore")
        db.add_all([wh_main, wh_site])
        await db.flush()

        # ── Locations ─────────────────────────────────────────────────────────
        locs = [
            WarehouseLocation(warehouse_id=wh_main.id, rack="R1", shelf="S1", description="Cement & Concrete"),
            WarehouseLocation(warehouse_id=wh_main.id, rack="R1", shelf="S2", description="Steel & Iron"),
            WarehouseLocation(warehouse_id=wh_main.id, rack="R2", shelf="S1", description="Wood & Timber"),
            WarehouseLocation(warehouse_id=wh_main.id, rack="R2", shelf="S2", description="Paint & Chemicals"),
            WarehouseLocation(warehouse_id=wh_main.id, rack="R3", shelf="S1", description="Electrical Items"),
            WarehouseLocation(warehouse_id=wh_main.id, rack="R3", shelf="S2", description="Plumbing Items"),
            WarehouseLocation(warehouse_id=wh_main.id, rack="R4", shelf="S1", description="Doors & Windows"),
            WarehouseLocation(warehouse_id=wh_site.id, rack="A1", shelf="S1", description="Site Mixed"),
        ]
        db.add_all(locs)
        await db.flush()
        loc_cement, loc_steel, loc_wood, loc_paint, loc_elec, loc_plumb, loc_doors, loc_site = locs

        # ── Categories ────────────────────────────────────────────────────────
        cats = {
            "Cement & Concrete": Category(name="Cement & Concrete", description="Cement, sand, aggregate, concrete blocks"),
            "Steel & Metal":     Category(name="Steel & Metal",     description="Rebar, steel rods, angles, sheets"),
            "Wood & Timber":     Category(name="Wood & Timber",     description="Timber, plywood, MDF, shuttering"),
            "Paint & Finish":    Category(name="Paint & Finish",    description="Paints, primers, varnishes, putty"),
            "Electrical":        Category(name="Electrical",        description="Wires, switches, panels, conduits"),
            "Plumbing":          Category(name="Plumbing",          description="Pipes, fittings, valves, taps"),
            "Doors & Windows":   Category(name="Doors & Windows",   description="Wooden/metal doors, windows, frames"),
            "Tiles & Flooring":  Category(name="Tiles & Flooring",  description="Ceramic tiles, marble, vinyl"),
            "Safety Equipment":  Category(name="Safety Equipment",  description="Helmets, gloves, safety belts"),
        }
        db.add_all(cats.values())
        await db.flush()

        # ── Inventory Items ───────────────────────────────────────────────────
        inv_items_data = [
            # (name, sku, cat_key, wh, loc, unit, qty, min_qty, unit_cost, desc)
            ("OPC Cement 50kg Bag",       "CEM-OPC-50",  "Cement & Concrete", wh_main, loc_cement, "bags",    350, 50,  650.0,  "Ordinary Portland Cement"),
            ("Coarse Sand",               "SND-CRS-01",  "Cement & Concrete", wh_main, loc_cement, "cft",     800, 100, 65.0,   "River coarse sand for concrete"),
            ("Fine Sand",                 "SND-FIN-01",  "Cement & Concrete", wh_main, loc_cement, "cft",     500, 80,  55.0,   "Fine plastering sand"),
            ("Crush (3/4 inch)",          "AGG-CRS-75",  "Cement & Concrete", wh_main, loc_cement, "cft",     600, 100, 80.0,   "Crushed stone aggregate 3/4 inch"),
            ("12mm Rebar Steel",          "STL-RBR-12",  "Steel & Metal",     wh_main, loc_steel,  "kg",      2000,300, 220.0,  "12mm TMT rebar for structure"),
            ("16mm Rebar Steel",          "STL-RBR-16",  "Steel & Metal",     wh_main, loc_steel,  "kg",      1500,200, 225.0,  "16mm TMT rebar for columns"),
            ("8mm Binding Wire",          "STL-BWR-08",  "Steel & Metal",     wh_main, loc_steel,  "kg",      200, 30,  180.0,  "Annealed binding wire"),
            ("2x4 Timber (12ft)",         "WD-TIM-24",   "Wood & Timber",     wh_main, loc_wood,   "pcs",     150, 20,  420.0,  "Deodar wood 2x4 shuttering"),
            ("12mm Plywood Sheet",        "WD-PLY-12",   "Wood & Timber",     wh_main, loc_wood,   "sheets",  80,  10,  1800.0, "12mm marine ply shuttering"),
            ("Emulsion Paint (20L)",      "PNT-EML-20",  "Paint & Finish",    wh_main, loc_paint,  "tins",    60,  10,  2200.0, "Interior white emulsion"),
            ("Exterior Paint (20L)",      "PNT-EXT-20",  "Paint & Finish",    wh_main, loc_paint,  "tins",    40,  8,   2800.0, "Weatherproof exterior paint"),
            ("Wall Putty 40kg",           "PNT-PUT-40",  "Paint & Finish",    wh_main, loc_paint,  "bags",    45,  10,  750.0,  "Acrylic wall putty"),
            ("7/29 Copper Wire (100m)",   "ELC-COP-29",  "Electrical",        wh_main, loc_elec,   "rolls",   30,  5,   3200.0, "7/29 copper house wire"),
            ("MCB 32A Single Pole",       "ELC-MCB-32",  "Electrical",        wh_main, loc_elec,   "pcs",     50,  10,  380.0,  "Schneider 32A MCB"),
            ("PVC Conduit 1 inch (3m)",   "ELC-CON-01",  "Electrical",        wh_main, loc_elec,   "pcs",     200, 30,  120.0,  "1 inch PVC conduit pipe"),
            ("UPVC Pipe 4inch (6m)",      "PLB-UPV-04",  "Plumbing",          wh_main, loc_plumb,  "pcs",     80,  15,  850.0,  "4 inch UPVC drain pipe"),
            ("PPR Pipe 25mm (4m)",        "PLB-PPR-25",  "Plumbing",          wh_main, loc_plumb,  "pcs",     120, 20,  380.0,  "25mm hot/cold PPR pipe"),
            ("Ball Valve 1 inch",         "PLB-BVL-01",  "Plumbing",          wh_main, loc_plumb,  "pcs",     60,  10,  250.0,  "Brass ball valve"),
            ("Solid Wood Door (7x3ft)",   "DR-SWD-73",   "Doors & Windows",   wh_main, loc_doors,  "pcs",     12,  3,   8500.0, "Solid deodar door with frame"),
            ("Aluminum Window (4x4ft)",   "WN-ALM-44",   "Doors & Windows",   wh_main, loc_doors,  "pcs",     20,  4,   6500.0, "Aluminum sliding window"),
            ("Ceramic Floor Tile 60x60",  "TL-CER-60",   "Tiles & Flooring",  wh_main, loc_cement, "boxes",   120, 20,  1400.0, "Matt ceramic floor tile 60x60cm"),
            ("Safety Helmet",             "SFT-HLM-01",  "Safety Equipment",  wh_main, loc_site,   "pcs",     25,  5,   350.0,  "ANSI hard hat"),
        ]

        inv_map = {}
        for data in inv_items_data:
            name, sku, cat_key, wh, loc, unit, qty, min_qty, ucost, desc = data
            item = InventoryItem(
                name=name, sku=sku,
                category_id=cats[cat_key].id,
                warehouse_id=wh.id,
                location_id=loc.id,
                unit=unit, quantity=qty, min_quantity=min_qty,
                unit_cost=ucost, description=desc,
            )
            db.add(item)
            inv_map[sku] = item
        await db.flush()

        # ── Suppliers ─────────────────────────────────────────────────────────
        sup_cement = Supplier(
            name="Al-Qadir Building Materials",
            contact_person="Qadir Ahmed",
            phone="+92-51-1234567",
            email="sales@alqadir.pk",
            address="Faizabad, Rawalpindi",
        )
        sup_steel = Supplier(
            name="Pak Steel Traders",
            contact_person="Tariq Mehmood",
            phone="+92-42-9876543",
            email="info@paksteel.pk",
            address="Steel Market, Lahore",
        )
        sup_elec = Supplier(
            name="National Electricals",
            contact_person="Usman Raza",
            phone="+92-51-5551234",
            email="contact@natelec.pk",
            address="Saddar Market, Rawalpindi",
        )
        db.add_all([sup_cement, sup_steel, sup_elec])
        await db.flush()

        # ── Purchases ─────────────────────────────────────────────────────────
        p1 = Purchase(
            purchase_number="PO-202501-0001",
            supplier_id=sup_cement.id,
            created_by=admin.id,
            status=PurchaseStatus.received,
            invoice_reference="INV-AQ-2025-001",
            notes="Monthly cement stock",
            purchase_date=datetime.utcnow() - timedelta(days=30),
            total_amount=0,
        )
        db.add(p1)
        await db.flush()

        pi1a = PurchaseItem(
            purchase_id=p1.id,
            inventory_item_id=inv_map["CEM-OPC-50"].id,
            quantity=200, unit_cost=640.0, total_cost=128000.0,
        )
        pi1b = PurchaseItem(
            purchase_id=p1.id,
            inventory_item_id=inv_map["SND-CRS-01"].id,
            quantity=400, unit_cost=62.0, total_cost=24800.0,
        )
        db.add_all([pi1a, pi1b])
        p1.total_amount = 152800.0
        await db.flush()

        p2 = Purchase(
            purchase_number="PO-202501-0002",
            supplier_id=sup_steel.id,
            created_by=manager.id,
            status=PurchaseStatus.received,
            invoice_reference="INV-PST-2025-007",
            purchase_date=datetime.utcnow() - timedelta(days=15),
            total_amount=0,
        )
        db.add(p2)
        await db.flush()
        pi2 = PurchaseItem(
            purchase_id=p2.id,
            inventory_item_id=inv_map["STL-RBR-12"].id,
            quantity=1000, unit_cost=218.0, total_cost=218000.0,
        )
        db.add(pi2)
        p2.total_amount = 218000.0
        await db.flush()

        # ── Projects ──────────────────────────────────────────────────────────
        proj1 = Project(
            name="DHA Phase 6 - Villa Construction",
            client_name="Mr. Salman Akhtar",
            client_phone="+92-300-1234567",
            address="Plot 45, DHA Phase 6, Lahore",
            status=ProjectStatus.active,
            budget=12000000.0,
            estimated_cost=9500000.0,
            actual_material_cost=0.0,
            labour_cost=2800000.0,
            other_cost=350000.0,
            description="5-marla double story villa with basement parking",
            start_date=datetime.utcnow() - timedelta(days=60),
            end_date=datetime.utcnow() + timedelta(days=120),
        )
        proj2 = Project(
            name="Bahria Town Office Renovation",
            client_name="Bahria Town Pvt Ltd",
            client_phone="+92-51-9999999",
            address="Bahria Town, Phase 4, Rawalpindi",
            status=ProjectStatus.active,
            budget=3500000.0,
            estimated_cost=2800000.0,
            actual_material_cost=0.0,
            labour_cost=800000.0,
            other_cost=100000.0,
            description="Complete renovation of 3rd-floor office block",
            start_date=datetime.utcnow() - timedelta(days=20),
            end_date=datetime.utcnow() + timedelta(days=50),
        )
        proj3 = Project(
            name="Gulberg Apartments - Grey Structure",
            client_name="Gulberg Developers",
            client_phone="+92-42-7778888",
            address="Main Boulevard Gulberg III, Lahore",
            status=ProjectStatus.completed,
            budget=25000000.0,
            estimated_cost=20000000.0,
            actual_material_cost=0.0,
            labour_cost=5500000.0,
            other_cost=750000.0,
            description="10-unit apartment grey structure",
            start_date=datetime.utcnow() - timedelta(days=300),
            end_date=datetime.utcnow() - timedelta(days=10),
        )
        db.add_all([proj1, proj2, proj3])
        await db.flush()

        # ── Material Usage ─────────────────────────────────────────────────────
        usages = [
            MaterialUsage(
                project_id=proj1.id,
                inventory_item_id=inv_map["CEM-OPC-50"].id,
                assigned_by=manager.id,
                usage_type=MaterialUsageType.assigned,
                quantity=80, unit_cost_at_time=650.0,
                total_cost=52000.0, notes="Foundation slab pour",
            ),
            MaterialUsage(
                project_id=proj1.id,
                inventory_item_id=inv_map["STL-RBR-12"].id,
                assigned_by=manager.id,
                usage_type=MaterialUsageType.assigned,
                quantity=500, unit_cost_at_time=220.0,
                total_cost=110000.0, notes="Column reinforcement",
            ),
            MaterialUsage(
                project_id=proj1.id,
                inventory_item_id=inv_map["STL-RBR-12"].id,
                assigned_by=manager.id,
                usage_type=MaterialUsageType.returned,
                quantity=20, unit_cost_at_time=220.0,
                total_cost=4400.0, notes="Surplus rebar returned",
            ),
            MaterialUsage(
                project_id=proj2.id,
                inventory_item_id=inv_map["PNT-EML-20"].id,
                assigned_by=worker.id,
                usage_type=MaterialUsageType.assigned,
                quantity=15, unit_cost_at_time=2200.0,
                total_cost=33000.0, notes="Interior emulsion coat",
            ),
            MaterialUsage(
                project_id=proj2.id,
                inventory_item_id=inv_map["TL-CER-60"].id,
                assigned_by=worker.id,
                usage_type=MaterialUsageType.assigned,
                quantity=30, unit_cost_at_time=1400.0,
                total_cost=42000.0, notes="Floor tiles, 3rd floor",
            ),
            MaterialUsage(
                project_id=proj3.id,
                inventory_item_id=inv_map["CEM-OPC-50"].id,
                assigned_by=manager.id,
                usage_type=MaterialUsageType.assigned,
                quantity=150, unit_cost_at_time=650.0,
                total_cost=97500.0, notes="Full structure concrete",
            ),
        ]
        db.add_all(usages)
        await db.flush()

        # update project material costs based on usages
        proj1.actual_material_cost = 52000.0 + 110000.0 - 4400.0   # 157600
        proj2.actual_material_cost = 33000.0 + 42000.0              # 75000
        proj3.actual_material_cost = 97500.0                        # 97500

        # update inventory quantities to match assignments
        inv_map["CEM-OPC-50"].quantity -= (80 + 150)    # used in proj1 + proj3
        inv_map["STL-RBR-12"].quantity -= (500 - 20)    # net usage proj1
        inv_map["PNT-EML-20"].quantity -= 15
        inv_map["TL-CER-60"].quantity  -= 30

        await db.commit()
        print("✅ Database seeded successfully!")
        print("\n📋 Login Credentials:")
        print("   Admin   → username: admin    | password: Admin@123")
        print("   Manager → username: manager  | password: Manager@123")
        print("   Worker  → username: worker   | password: Worker@123")
        print("\n📦 Seeded:")
        print(f"   {len(inv_items_data)} inventory items across {len(cats)} categories")
        print(f"   3 suppliers, 2 purchases, 3 projects")
        print(f"   {len(usages)} material usage records")


if __name__ == "__main__":
    asyncio.run(seed())
