import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/common_widgets.dart';

class AddEditInventoryScreen extends StatefulWidget {
  final InventoryItem? item;
  const AddEditInventoryScreen({super.key, this.item});

  @override
  State<AddEditInventoryScreen> createState() => _AddEditInventoryScreenState();
}

class _AddEditInventoryScreenState extends State<AddEditInventoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _minQtyCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  List<Category> _categories = [];
  List<Warehouse> _warehouses = [];
  List<WarehouseLocation> _locations = [];

  int? _selectedCategoryId;
  int? _selectedWarehouseId;
  int? _selectedLocationId;

  bool _loading = false;
  bool _initializing = true;

  bool get _isEdit => widget.item != null;

  static const _units = [
    'bags', 'kg', 'pcs', 'meters', 'feet', 'cft', 'sheets',
    'rolls', 'tins', 'boxes', 'liters', 'sets', 'pairs', 'tons'
  ];

  @override
  void initState() {
    super.initState();
    _initForm();
  }

  Future<void> _initForm() async {
    try {
      final results = await Future.wait([
        _api.getCategories(),
        _api.getWarehouses(),
        _api.getLocations(),
      ]);
      _categories = results[0] as List<Category>;
      _warehouses = results[1] as List<Warehouse>;
      _locations = results[2] as List<WarehouseLocation>;

      if (_isEdit) {
        final it = widget.item!;
        _nameCtrl.text = it.name;
        _skuCtrl.text = it.sku;
        _unitCtrl.text = it.unit;
        _qtyCtrl.text = it.quantity.toString();
        _minQtyCtrl.text = it.minQuantity.toString();
        _costCtrl.text = it.unitCost.toString();
        _descCtrl.text = it.description ?? '';
        _selectedCategoryId = it.categoryId;
        _selectedWarehouseId = it.warehouseId;
        _selectedLocationId = it.locationId;
      }
    } catch (e) {
      if (mounted) showError(context, 'Failed to load form data: $e');
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  List<WarehouseLocation> get _filteredLocations => _selectedWarehouseId == null
      ? _locations
      : _locations.where((l) => l.warehouseId == _selectedWarehouseId).toList();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final body = {
        'name': _nameCtrl.text.trim(),
        'sku': _skuCtrl.text.trim(),
        'unit': _unitCtrl.text.trim(),
        'quantity': double.tryParse(_qtyCtrl.text) ?? 0.0,
        'min_quantity': double.tryParse(_minQtyCtrl.text) ?? 0.0,
        'unit_cost': double.tryParse(_costCtrl.text) ?? 0.0,
        if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
        if (_selectedCategoryId != null) 'category_id': _selectedCategoryId,
        if (_selectedWarehouseId != null) 'warehouse_id': _selectedWarehouseId,
        if (_selectedLocationId != null) 'location_id': _selectedLocationId,
      };
      if (_isEdit) {
        await _api.updateInventoryItem(widget.item!.id, body);
        if (mounted) showSuccess(context, 'Item updated successfully');
      } else {
        await _api.createInventoryItem(body);
        if (mounted) showSuccess(context, 'Item added successfully');
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _skuCtrl.dispose(); _unitCtrl.dispose();
    _qtyCtrl.dispose(); _minQtyCtrl.dispose(); _costCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Item' : 'Add Inventory Item'),
        actions: [
          if (!_loading && !_initializing)
            TextButton(
              onPressed: _save,
              child: const Text('SAVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : LoadingOverlay(
              isLoading: _loading,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('Basic Information'),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _nameCtrl,
                        label: 'Item Name *',
                        prefixIcon: Icons.inventory_2_outlined,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _skuCtrl,
                        label: 'SKU / Item Code *',
                        prefixIcon: Icons.qr_code_outlined,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'SKU is required' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildUnitDropdown(),
                      const SizedBox(height: 24),
                      _sectionTitle('Quantity & Pricing'),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: AppTextField(
                            controller: _qtyCtrl,
                            label: 'Current Qty',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            prefixIcon: Icons.numbers,
                            validator: (v) => (v != null && v.isNotEmpty && double.tryParse(v) == null)
                                ? 'Invalid number' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            controller: _minQtyCtrl,
                            label: 'Min Qty (Alert)',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            prefixIcon: Icons.warning_amber_outlined,
                            validator: (v) => (v != null && v.isNotEmpty && double.tryParse(v) == null)
                                ? 'Invalid number' : null,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _costCtrl,
                        label: 'Unit Cost (PKR)',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        prefixIcon: Icons.attach_money_outlined,
                        validator: (v) => (v != null && v.isNotEmpty && double.tryParse(v) == null)
                            ? 'Invalid amount' : null,
                      ),
                      const SizedBox(height: 24),
                      _sectionTitle('Storage Location'),
                      const SizedBox(height: 12),
                      _buildCategoryDropdown(),
                      const SizedBox(height: 12),
                      _buildWarehouseDropdown(),
                      const SizedBox(height: 12),
                      _buildLocationDropdown(),
                      const SizedBox(height: 24),
                      _sectionTitle('Notes'),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _descCtrl,
                        label: 'Description / Notes',
                        prefixIcon: Icons.notes_outlined,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _loading ? null : _save,
                        child: Text(_isEdit ? 'Update Item' : 'Add Item'),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
          color: AppColors.textSecondary, letterSpacing: 0.5));

  Widget _buildUnitDropdown() {
    final isCustom = _unitCtrl.text.isNotEmpty && !_units.contains(_unitCtrl.text);
    return DropdownButtonFormField<String>(
      value: _units.contains(_unitCtrl.text) ? _unitCtrl.text : null,
      decoration: const InputDecoration(
        labelText: 'Unit of Measurement *',
        prefixIcon: Icon(Icons.straighten_outlined, size: 20),
      ),
      items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
      onChanged: (v) { if (v != null) setState(() => _unitCtrl.text = v); },
      validator: (_) => _unitCtrl.text.trim().isEmpty ? 'Unit is required' : null,
      hint: isCustom ? Text(_unitCtrl.text) : const Text('Select unit'),
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<int?>(
      value: _selectedCategoryId,
      decoration: const InputDecoration(
        labelText: 'Category',
        prefixIcon: Icon(Icons.category_outlined, size: 20),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('No Category')),
        ..._categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
      ],
      onChanged: (v) => setState(() => _selectedCategoryId = v),
    );
  }

  Widget _buildWarehouseDropdown() {
    return DropdownButtonFormField<int?>(
      value: _selectedWarehouseId,
      decoration: const InputDecoration(
        labelText: 'Warehouse',
        prefixIcon: Icon(Icons.warehouse_outlined, size: 20),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('No Warehouse')),
        ..._warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))),
      ],
      onChanged: (v) => setState(() {
        _selectedWarehouseId = v;
        _selectedLocationId = null;
      }),
    );
  }

  Widget _buildLocationDropdown() {
    final locs = _filteredLocations;
    return DropdownButtonFormField<int?>(
      value: locs.any((l) => l.id == _selectedLocationId) ? _selectedLocationId : null,
      decoration: const InputDecoration(
        labelText: 'Rack / Shelf Location',
        prefixIcon: Icon(Icons.shelves, size: 20),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('No Location')),
        ...locs.map((l) => DropdownMenuItem(
            value: l.id, child: Text('${l.rack} / ${l.shelf}${l.description != null ? ' — ${l.description}' : ''}'))),
      ],
      onChanged: (v) => setState(() => _selectedLocationId = v),
    );
  }
}
