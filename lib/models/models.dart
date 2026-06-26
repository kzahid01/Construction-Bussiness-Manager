// ─── User ─────────────────────────────────────────────────────────────────────

class User {
  final int id;
  final String username;
  final String email;
  final String fullName;
  final String role;
  final bool isActive;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isActive,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'],
        username: j['username'],
        email: j['email'],
        fullName: j['full_name'],
        role: j['role'],
        isActive: j['is_active'] ?? true,
      );
}

// ─── Category ─────────────────────────────────────────────────────────────────

class Category {
  final int id;
  final String name;
  final String? description;

  Category({required this.id, required this.name, this.description});

  factory Category.fromJson(Map<String, dynamic> j) =>
      Category(id: j['id'], name: j['name'], description: j['description']);
}

// ─── Warehouse ────────────────────────────────────────────────────────────────

class Warehouse {
  final int id;
  final String name;
  final String? address;

  Warehouse({required this.id, required this.name, this.address});

  factory Warehouse.fromJson(Map<String, dynamic> j) =>
      Warehouse(id: j['id'], name: j['name'], address: j['address']);
}

class WarehouseLocation {
  final int id;
  final int warehouseId;
  final String rack;
  final String shelf;
  final String? description;

  WarehouseLocation({
    required this.id,
    required this.warehouseId,
    required this.rack,
    required this.shelf,
    this.description,
  });

  String get label => 'Rack $rack / Shelf $shelf';

  factory WarehouseLocation.fromJson(Map<String, dynamic> j) =>
      WarehouseLocation(
        id: j['id'],
        warehouseId: j['warehouse_id'],
        rack: j['rack'],
        shelf: j['shelf'],
        description: j['description'],
      );
}

// ─── Inventory Item ───────────────────────────────────────────────────────────

class InventoryItem {
  final int id;
  final String name;
  final String sku;
  final int? categoryId;
  final int? warehouseId;
  final int? locationId;
  final String unit;
  final double quantity;
  final double minQuantity;
  final double unitCost;
  final String? description;
  final bool isActive;
  final Category? category;
  final Warehouse? warehouse;
  final WarehouseLocation? location;

  bool get isLowStock => quantity <= minQuantity;
  double get totalValue => quantity * unitCost;

  InventoryItem({
    required this.id,
    required this.name,
    required this.sku,
    this.categoryId,
    this.warehouseId,
    this.locationId,
    required this.unit,
    required this.quantity,
    required this.minQuantity,
    required this.unitCost,
    this.description,
    this.isActive = true,
    this.category,
    this.warehouse,
    this.location,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> j) => InventoryItem(
        id: j['id'],
        name: j['name'],
        sku: j['sku'],
        categoryId: j['category_id'],
        warehouseId: j['warehouse_id'],
        locationId: j['location_id'],
        unit: j['unit'],
        quantity: (j['quantity'] as num).toDouble(),
        minQuantity: (j['min_quantity'] as num).toDouble(),
        unitCost: (j['unit_cost'] as num).toDouble(),
        description: j['description'],
        isActive: j['is_active'] ?? true,
        category: j['category'] != null ? Category.fromJson(j['category']) : null,
        warehouse: j['warehouse'] != null ? Warehouse.fromJson(j['warehouse']) : null,
        location: j['location'] != null ? WarehouseLocation.fromJson(j['location']) : null,
      );
}

// ─── Supplier ─────────────────────────────────────────────────────────────────

class Supplier {
  final int id;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final bool isActive;

  Supplier({
    required this.id,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.isActive = true,
  });

  factory Supplier.fromJson(Map<String, dynamic> j) => Supplier(
        id: j['id'],
        name: j['name'],
        contactPerson: j['contact_person'],
        phone: j['phone'],
        email: j['email'],
        address: j['address'],
        isActive: j['is_active'] ?? true,
      );
}

// ─── Purchase ─────────────────────────────────────────────────────────────────

class PurchaseItem {
  final int id;
  final int inventoryItemId;
  final double quantity;
  final double unitCost;
  final double totalCost;
  final InventoryItem? inventoryItem;

  PurchaseItem({
    required this.id,
    required this.inventoryItemId,
    required this.quantity,
    required this.unitCost,
    required this.totalCost,
    this.inventoryItem,
  });

  factory PurchaseItem.fromJson(Map<String, dynamic> j) => PurchaseItem(
        id: j['id'],
        inventoryItemId: j['inventory_item_id'],
        quantity: (j['quantity'] as num).toDouble(),
        unitCost: (j['unit_cost'] as num).toDouble(),
        totalCost: (j['total_cost'] as num).toDouble(),
        inventoryItem: j['inventory_item'] != null
            ? InventoryItem.fromJson(j['inventory_item'])
            : null,
      );
}

class Purchase {
  final int id;
  final String purchaseNumber;
  final int? supplierId;
  final String status;
  final String? invoiceReference;
  final String? notes;
  final double totalAmount;
  final DateTime purchaseDate;
  final Supplier? supplier;
  final List<PurchaseItem> items;

  Purchase({
    required this.id,
    required this.purchaseNumber,
    this.supplierId,
    required this.status,
    this.invoiceReference,
    this.notes,
    required this.totalAmount,
    required this.purchaseDate,
    this.supplier,
    this.items = const [],
  });

  factory Purchase.fromJson(Map<String, dynamic> j) => Purchase(
        id: j['id'],
        purchaseNumber: j['purchase_number'],
        supplierId: j['supplier_id'],
        status: j['status'],
        invoiceReference: j['invoice_reference'],
        notes: j['notes'],
        totalAmount: (j['total_amount'] as num).toDouble(),
        purchaseDate: DateTime.parse(j['purchase_date']),
        supplier: j['supplier'] != null ? Supplier.fromJson(j['supplier']) : null,
        items: (j['items'] as List? ?? [])
            .map((e) => PurchaseItem.fromJson(e))
            .toList(),
      );
}

// ─── Project ──────────────────────────────────────────────────────────────────

class Project {
  final int id;
  final String name;
  final String? clientName;
  final String? clientPhone;
  final String? address;
  final String status;
  final double budget;
  final double estimatedCost;
  final double actualMaterialCost;
  final double labourCost;
  final double otherCost;
  final String? description;
  final DateTime? startDate;
  final DateTime? endDate;
  final double totalCost;
  final double profit;
  final double profitMargin;

  Project({
    required this.id,
    required this.name,
    this.clientName,
    this.clientPhone,
    this.address,
    required this.status,
    required this.budget,
    required this.estimatedCost,
    required this.actualMaterialCost,
    required this.labourCost,
    required this.otherCost,
    this.description,
    this.startDate,
    this.endDate,
    required this.totalCost,
    required this.profit,
    required this.profitMargin,
  });

  factory Project.fromJson(Map<String, dynamic> j) => Project(
        id: j['id'],
        name: j['name'],
        clientName: j['client_name'],
        clientPhone: j['client_phone'],
        address: j['address'],
        status: j['status'],
        budget: (j['budget'] as num).toDouble(),
        estimatedCost: (j['estimated_cost'] as num).toDouble(),
        actualMaterialCost: (j['actual_material_cost'] as num).toDouble(),
        labourCost: (j['labour_cost'] as num).toDouble(),
        otherCost: (j['other_cost'] as num).toDouble(),
        description: j['description'],
        startDate: j['start_date'] != null ? DateTime.parse(j['start_date']) : null,
        endDate: j['end_date'] != null ? DateTime.parse(j['end_date']) : null,
        totalCost: (j['total_cost'] as num).toDouble(),
        profit: (j['profit'] as num).toDouble(),
        profitMargin: (j['profit_margin'] as num).toDouble(),
      );
}

// ─── Material Usage ───────────────────────────────────────────────────────────

class MaterialUsage {
  final int id;
  final int projectId;
  final int inventoryItemId;
  final String usageType;
  final double quantity;
  final double unitCostAtTime;
  final double totalCost;
  final String? notes;
  final DateTime createdAt;
  final InventoryItem? inventoryItem;

  MaterialUsage({
    required this.id,
    required this.projectId,
    required this.inventoryItemId,
    required this.usageType,
    required this.quantity,
    required this.unitCostAtTime,
    required this.totalCost,
    this.notes,
    required this.createdAt,
    this.inventoryItem,
  });

  factory MaterialUsage.fromJson(Map<String, dynamic> j) => MaterialUsage(
        id: j['id'],
        projectId: j['project_id'],
        inventoryItemId: j['inventory_item_id'],
        usageType: j['usage_type'],
        quantity: (j['quantity'] as num).toDouble(),
        unitCostAtTime: (j['unit_cost_at_time'] as num).toDouble(),
        totalCost: (j['total_cost'] as num).toDouble(),
        notes: j['notes'],
        createdAt: DateTime.parse(j['created_at']),
        inventoryItem: j['inventory_item'] != null
            ? InventoryItem.fromJson(j['inventory_item'])
            : null,
      );
}

// ─── Dashboard Stats ──────────────────────────────────────────────────────────

class DashboardStats {
  final int totalInventoryItems;
  final int lowStockItems;
  final double totalInventoryValue;
  final int activeProjects;
  final int totalProjects;
  final int totalPurchases;
  final double recentPurchasesValue;

  DashboardStats({
    required this.totalInventoryItems,
    required this.lowStockItems,
    required this.totalInventoryValue,
    required this.activeProjects,
    required this.totalProjects,
    required this.totalPurchases,
    required this.recentPurchasesValue,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> j) => DashboardStats(
        totalInventoryItems: j['total_inventory_items'],
        lowStockItems: j['low_stock_items'],
        totalInventoryValue: (j['total_inventory_value'] as num).toDouble(),
        activeProjects: j['active_projects'],
        totalProjects: j['total_projects'],
        totalPurchases: j['total_purchases'],
        recentPurchasesValue: (j['recent_purchases_value'] as num).toDouble(),
      );
}

// ─── Stock Summary Item ───────────────────────────────────────────────────────

class StockSummaryItem {
  final int id;
  final String name;
  final String sku;
  final String unit;
  final double quantity;
  final double minQuantity;
  final double unitCost;
  final double totalValue;
  final bool isLowStock;
  final String? categoryName;
  final String? warehouseName;

  StockSummaryItem({
    required this.id,
    required this.name,
    required this.sku,
    required this.unit,
    required this.quantity,
    required this.minQuantity,
    required this.unitCost,
    required this.totalValue,
    required this.isLowStock,
    this.categoryName,
    this.warehouseName,
  });

  factory StockSummaryItem.fromJson(Map<String, dynamic> j) => StockSummaryItem(
        id: j['id'],
        name: j['name'],
        sku: j['sku'],
        unit: j['unit'],
        quantity: (j['quantity'] as num).toDouble(),
        minQuantity: (j['min_quantity'] as num).toDouble(),
        unitCost: (j['unit_cost'] as num).toDouble(),
        totalValue: (j['total_value'] as num).toDouble(),
        isLowStock: j['is_low_stock'] ?? false,
        categoryName: j['category_name'],
        warehouseName: j['warehouse_name'],
      );
}
