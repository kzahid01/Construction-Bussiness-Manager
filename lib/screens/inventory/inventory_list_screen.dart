import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/common_widgets.dart';
import 'add_edit_inventory_screen.dart';

class InventoryListScreen extends StatefulWidget {
  final bool lowStockOnly;
  const InventoryListScreen({super.key, this.lowStockOnly = false});

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();
  List<InventoryItem> _items = [];
  List<Category> _categories = [];
  bool _loading = true;
  String? _error;
  int? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.getInventoryItems(
          search: _searchCtrl.text.isEmpty ? null : _searchCtrl.text,
          categoryId: _selectedCategory,
          lowStockOnly: widget.lowStockOnly,
        ),
        _api.getCategories(),
      ]);
      if (mounted) {
        setState(() {
          _items = results[0] as List<InventoryItem>;
          _categories = results[1] as List<Category>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _delete(InventoryItem item) async {
    final ok = await showConfirmDialog(context,
        title: 'Delete Item',
        message: 'Delete "${item.name}"? This cannot be undone.');
    if (!ok || !mounted) return;
    try {
      await _api.deleteInventoryItem(item.id);
      showSuccess(context, 'Item deleted');
      _load();
    } catch (e) {
      showError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.lowStockOnly ? 'Low Stock Items' : 'Inventory'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AddEditInventoryScreen()));
          _load();
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_categories.isNotEmpty) _buildCategoryFilter(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? ErrorBanner(message: _error!, onRetry: _load)
                    : _items.isEmpty
                        ? EmptyState(
                            icon: Icons.inventory_2_outlined,
                            title: 'No items found',
                            subtitle: 'Add inventory items to get started',
                            actionLabel: 'Add Item',
                            onAction: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const AddEditInventoryScreen()))
                                .then((_) => _load()),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                              itemCount: _items.length,
                              itemBuilder: (_, i) => _buildItemCard(_items[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search by name or SKU...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
          prefixIcon:
              Icon(Icons.search, color: Colors.white.withOpacity(0.8)),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close,
                      color: Colors.white.withOpacity(0.8)),
                  onPressed: () {
                    _searchCtrl.clear();
                    _load();
                  })
              : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: Colors.white38),
          ),
        ),
        onSubmitted: (_) => _load(),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 44,
      color: AppColors.surface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          _CategoryChip(
            label: 'All',
            selected: _selectedCategory == null,
            onTap: () {
              setState(() => _selectedCategory = null);
              _load();
            },
          ),
          ..._categories.map((c) => _CategoryChip(
                label: c.name,
                selected: _selectedCategory == c.id,
                onTap: () {
                  setState(() => _selectedCategory = c.id);
                  _load();
                },
              )),
        ],
      ),
    );
  }

  Widget _buildItemCard(InventoryItem item) {
    return Slidable(
      key: ValueKey(item.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AddEditInventoryScreen(item: item)));
              _load();
            },
            backgroundColor: AppColors.primaryLight,
            foregroundColor: Colors.white,
            icon: Icons.edit_outlined,
            label: 'Edit',
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                bottomLeft: Radius.circular(10)),
          ),
          SlidableAction(
            onPressed: (_) => _delete(item),
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Delete',
            borderRadius: const BorderRadius.only(
                topRight: Radius.circular(10),
                bottomRight: Radius.circular(10)),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: item.isLowStock
              ? Border.all(color: AppColors.danger.withOpacity(0.4))
              : null,
          boxShadow: [
            BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text('SKU: ${item.sku}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  if (item.isLowStock)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('LOW',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.danger)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _ItemStat(
                    label: 'Qty',
                    value: '${formatNum(item.quantity)} ${item.unit}',
                    color: item.isLowStock ? AppColors.danger : null,
                  ),
                  const SizedBox(width: 20),
                  _ItemStat(
                    label: 'Unit Cost',
                    value: formatPKR(item.unitCost),
                  ),
                  const SizedBox(width: 20),
                  _ItemStat(
                    label: 'Total Value',
                    value: formatPKR(item.totalValue),
                    color: AppColors.primary,
                  ),
                ],
              ),
              if (item.category != null || item.warehouse != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    if (item.category != null)
                      _Tag(item.category!.name, AppColors.primary),
                    if (item.warehouse != null)
                      _Tag(item.warehouse!.name, AppColors.success),
                    if (item.location != null)
                      _Tag(item.location!.label, Colors.purple),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : AppColors.textSecondary)),
        ),
      ),
    );
  }
}

class _ItemStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _ItemStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: AppColors.textSecondary)),
        Text(value,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color ?? AppColors.textPrimary)),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w500, color: color)),
    );
  }
}
