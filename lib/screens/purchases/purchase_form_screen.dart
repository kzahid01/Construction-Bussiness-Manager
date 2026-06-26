import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/common_widgets.dart';

class _LineItem {
  InventoryItem? item;
  final qtyCtrl = TextEditingController();
  final costCtrl = TextEditingController();
  _LineItem();
  void dispose() { qtyCtrl.dispose(); costCtrl.dispose(); }
  double get lineTotal => (double.tryParse(qtyCtrl.text) ?? 0) *
      (double.tryParse(costCtrl.text) ?? 0);
}

class PurchaseFormScreen extends StatefulWidget {
  const PurchaseFormScreen({super.key});

  @override
  State<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends State<PurchaseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  final _invoiceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  List<InventoryItem> _inventoryItems = [];
  List<Supplier> _suppliers = [];
  Supplier? _selectedSupplier;
  DateTime _purchaseDate = DateTime.now();

  final List<_LineItem> _lines = [_LineItem()];

  bool _loading = false;
  bool _initializing = true;

  @override
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    try {
      final results = await Future.wait([_api.getInventoryItems(), _api.getSuppliers()]);
      if (mounted) setState(() {
        _inventoryItems = results[0] as List<InventoryItem>;
        _suppliers = results[1] as List<Supplier>;
        _initializing = false;
      });
    } catch (e) {
      if (mounted) { showError(context, e.toString()); setState(() => _initializing = false); }
    }
  }

  @override
  void dispose() {
    _invoiceCtrl.dispose(); _notesCtrl.dispose();
    for (final l in _lines) l.dispose();
    super.dispose();
  }

  double get _grandTotal => _lines.fold(0, (s, l) => s + l.lineTotal);

  void _addLine() => setState(() => _lines.add(_LineItem()));

  void _removeLine(int i) {
    if (_lines.length == 1) return;
    setState(() { _lines[i].dispose(); _lines.removeAt(i); });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _purchaseDate = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate all lines
    for (int i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      if (l.item == null) { showError(context, 'Select an item for row ${i + 1}'); return; }
      if ((double.tryParse(l.qtyCtrl.text) ?? 0) <= 0) { showError(context, 'Enter valid qty for row ${i + 1}'); return; }
      if ((double.tryParse(l.costCtrl.text) ?? 0) <= 0) { showError(context, 'Enter valid cost for row ${i + 1}'); return; }
    }

    setState(() => _loading = true);
    try {
      final body = {
        if (_selectedSupplier != null) 'supplier_id': _selectedSupplier!.id,
        if (_invoiceCtrl.text.isNotEmpty) 'invoice_reference': _invoiceCtrl.text.trim(),
        if (_notesCtrl.text.isNotEmpty) 'notes': _notesCtrl.text.trim(),
        'purchase_date': _purchaseDate.toIso8601String(),
        'items': _lines.map((l) => {
          'inventory_item_id': l.item!.id,
          'quantity': double.parse(l.qtyCtrl.text),
          'unit_cost': double.parse(l.costCtrl.text),
        }).toList(),
      };
      await _api.createPurchase(body);
      if (mounted) {
        showSuccess(context, 'Purchase recorded & stock updated');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Purchase'),
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
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sec('Purchase Info'),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<Supplier?>(
                              value: _selectedSupplier,
                              decoration: const InputDecoration(
                                labelText: 'Supplier (optional)',
                                prefixIcon: Icon(Icons.store_outlined, size: 20),
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('No Supplier')),
                                ..._suppliers.map((s) => DropdownMenuItem(value: s, child: Text(s.name))),
                              ],
                              onChanged: (v) => setState(() => _selectedSupplier = v),
                            ),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(child: AppTextField(
                                controller: _invoiceCtrl,
                                label: 'Invoice Reference',
                                prefixIcon: Icons.receipt_outlined,
                              )),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: _pickDate,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.divider),
                                  ),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                                    const Icon(Icons.calendar_today_outlined, size: 16,
                                        color: AppColors.textSecondary),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_purchaseDate.day.toString().padLeft(2, '0')}-'
                                      '${_purchaseDate.month.toString().padLeft(2, '0')}-'
                                      '${_purchaseDate.year}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                    ),
                                  ]),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 12),
                            AppTextField(controller: _notesCtrl, label: 'Notes (optional)',
                                prefixIcon: Icons.notes_outlined, maxLines: 2),
                            const SizedBox(height: 24),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              _sec('Items'),
                              TextButton.icon(
                                onPressed: _addLine,
                                icon: const Icon(Icons.add_circle_outline, size: 16),
                                label: const Text('Add Row'),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            ..._lines.asMap().entries.map((e) => _buildLine(e.key, e.value)),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                    // Grand Total + Save
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, -4))],
                      ),
                      child: Row(children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Grand Total', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          Text(formatPKR(_grandTotal),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
                        ]),
                        const Spacer(),
                        SizedBox(
                          width: 140,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _save,
                            child: const Text('Save Purchase'),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLine(int i, _LineItem line) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<InventoryItem>(
              value: line.item,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Item *',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: _inventoryItems.map((inv) => DropdownMenuItem(
                  value: inv,
                  child: Text(inv.name, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() {
                line.item = v;
                if (v != null && line.costCtrl.text.isEmpty) {
                  line.costCtrl.text = v.unitCost.toStringAsFixed(0);
                }
              }),
            ),
          ),
          if (_lines.length > 1) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _removeLine(i),
              icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger, size: 22),
              padding: EdgeInsets.zero,
            ),
          ],
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextFormField(
              controller: line.qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Quantity *',
                suffixText: line.item?.unit ?? '',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: line.costCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Unit Cost (PKR) *',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('Total', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            Text(formatPKR(line.lineTotal),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ]),
        ]),
      ]),
    );
  }

  Widget _sec(String t) => Text(t, style: const TextStyle(
      fontSize: 13, fontWeight: FontWeight.w700,
      color: AppColors.textSecondary, letterSpacing: 0.5));
}
