import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/common_widgets.dart';
import 'project_form_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  final int projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabCtrl;

  Project? _project;
  List<MaterialUsage> _usages = [];
  List<InventoryItem> _inventoryItems = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.getProject(widget.projectId),
        _api.getProjectMaterials(widget.projectId),
        _api.getInventoryItems(),
      ]);
      if (mounted) setState(() {
        _project = results[0] as Project;
        _usages = results[1] as List<MaterialUsage>;
        _inventoryItems = results[2] as List<InventoryItem>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _showMaterialDialog({required bool isReturn}) async {
    InventoryItem? selectedItem;
    final qtyCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(isReturn ? Icons.undo_outlined : Icons.add_shopping_cart_outlined,
                    color: isReturn ? AppColors.warning : AppColors.primary),
                const SizedBox(width: 8),
                Text(isReturn ? 'Return Material' : 'Assign Material',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 16),
              DropdownButtonFormField<InventoryItem>(
                value: selectedItem,
                decoration: const InputDecoration(labelText: 'Select Item *'),
                items: _inventoryItems.where((i) => i.quantity > 0 || isReturn).map((i) =>
                    DropdownMenuItem(value: i,
                        child: Text('${i.name} (${formatNum(i.quantity)} ${i.unit})',
                            overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setSheetState(() => selectedItem = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Quantity *',
                  suffixText: selectedItem?.unit ?? '',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (selectedItem == null || qtyCtrl.text.isEmpty) {
                    showError(ctx, 'Please select item and enter quantity');
                    return;
                  }
                  final qty = double.tryParse(qtyCtrl.text);
                  if (qty == null || qty <= 0) {
                    showError(ctx, 'Enter a valid quantity');
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    if (isReturn) {
                      await _api.returnMaterial(widget.projectId, selectedItem!.id, qty,
                          notes: notesCtrl.text.isEmpty ? null : notesCtrl.text);
                      if (mounted) showSuccess(context, 'Material returned to stock');
                    } else {
                      await _api.assignMaterial(widget.projectId, selectedItem!.id, qty,
                          notes: notesCtrl.text.isEmpty ? null : notesCtrl.text);
                      if (mounted) showSuccess(context, 'Material assigned to project');
                    }
                    _load();
                  } catch (e) {
                    if (mounted) showError(context, e.toString());
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isReturn ? AppColors.warning : AppColors.primary,
                ),
                child: Text(isReturn ? 'Return to Stock' : 'Assign to Project'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(body: ErrorBanner(message: _error!, onRetry: _load));

    final p = _project!;

    return Scaffold(
      appBar: AppBar(
        title: Text(p.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => ProjectFormScreen(project: p)));
              _load();
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [Tab(text: 'OVERVIEW'), Tab(text: 'MATERIALS')],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // ── Overview Tab ────────────────────────────────────────────────
          RefreshIndicator(
            onRefresh: _load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status + Client
                  _InfoCard(children: [
                    _Row('Status', StatusBadge(status: p.status)),
                    if (p.clientName != null) _Row('Client', Text(p.clientName!, style: const TextStyle(fontWeight: FontWeight.w500))),
                    if (p.clientPhone != null) _Row('Phone', Text(p.clientPhone!)),
                    if (p.address != null) _Row('Address', Flexible(child: Text(p.address!, style: const TextStyle(fontSize: 13)))),
                    if (p.startDate != null) _Row('Start', Text(_fmtDate(p.startDate!))),
                    if (p.endDate != null) _Row('End', Text(_fmtDate(p.endDate!))),
                  ]),
                  const SizedBox(height: 16),
                  // Financials
                  _SectionLabel('Financial Summary'),
                  const SizedBox(height: 8),
                  _FinCard(
                    rows: [
                      _FinRow('Contract Budget', p.budget, AppColors.primary),
                      _FinRow('Material Cost', p.actualMaterialCost, AppColors.textSecondary),
                      _FinRow('Labour Cost', p.labourCost, AppColors.textSecondary),
                      _FinRow('Other Cost', p.otherCost, AppColors.textSecondary),
                    ],
                    totalLabel: 'Total Cost',
                    totalValue: p.totalCost,
                    profitLabel: 'Net Profit',
                    profit: p.profit,
                    profitMargin: p.profitMargin,
                  ),
                  if (p.description != null && p.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SectionLabel('Description'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 6)],
                      ),
                      child: Text(p.description!, style: const TextStyle(fontSize: 13, height: 1.5)),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showMaterialDialog(isReturn: false),
                        icon: const Icon(Icons.add_shopping_cart_outlined, size: 18),
                        label: const Text('Assign Material'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showMaterialDialog(isReturn: true),
                        icon: const Icon(Icons.undo_outlined, size: 18),
                        label: const Text('Return Material'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),

          // ── Materials Tab ───────────────────────────────────────────────
          _usages.isEmpty
              ? EmptyState(
                  icon: Icons.category_outlined,
                  title: 'No material transactions',
                  subtitle: 'Assign materials from the Overview tab',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _usages.length,
                  itemBuilder: (_, i) => _buildUsageCard(_usages[i]),
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showMaterialDialog(isReturn: false),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Assign', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildUsageCard(MaterialUsage u) {
    final isReturn = u.usageType == 'returned';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: isReturn ? AppColors.warning : AppColors.primary,
            width: 3,
          ),
        ),
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Icon(isReturn ? Icons.undo_outlined : Icons.assignment_outlined,
            color: isReturn ? AppColors.warning : AppColors.primary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u.inventoryItem?.name ?? 'Item #${u.inventoryItemId}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 3),
            Text('${formatNum(u.quantity)} ${u.inventoryItem?.unit ?? ''} @ ${formatPKR(u.unitCostAtTime)}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            if (u.notes != null)
              Text(u.notes!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(isReturn ? '+ ${formatPKR(u.totalCost)}' : '- ${formatPKR(u.totalCost)}',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13,
                  color: isReturn ? AppColors.warning : AppColors.danger)),
          const SizedBox(height: 3),
          Text(_fmtDate(u.createdAt),
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ]),
      ]),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 6)],
    ),
    child: Column(children: children),
  );
}

class _Row extends StatelessWidget {
  final String label; final Widget value;
  const _Row(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 90, child: Text(label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
      Expanded(child: value),
    ]),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
          color: AppColors.textSecondary, letterSpacing: 0.5));
}

class _FinCard extends StatelessWidget {
  final List<_FinRow> rows;
  final String totalLabel; final double totalValue;
  final String profitLabel; final double profit; final double profitMargin;
  const _FinCard({required this.rows, required this.totalLabel,
    required this.totalValue, required this.profitLabel,
    required this.profit, required this.profitMargin});
  @override
  Widget build(BuildContext context) {
    final isPos = profit >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 6)],
      ),
      child: Column(children: [
        ...rows.map((r) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(r.label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            Text(formatPKR(r.value),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: r.color)),
          ]),
        )),
        const Divider(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(totalLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          Text(formatPKR(totalValue),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: (isPos ? AppColors.success : AppColors.danger).withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(profitLabel,
                style: TextStyle(fontWeight: FontWeight.w700,
                    color: isPos ? AppColors.success : AppColors.danger)),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(formatPKR(profit),
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16,
                      color: isPos ? AppColors.success : AppColors.danger)),
              Text('${profitMargin.toStringAsFixed(1)}% margin',
                  style: TextStyle(fontSize: 11,
                      color: isPos ? AppColors.success : AppColors.danger)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _FinRow {
  final String label; final double value; final Color color;
  const _FinRow(this.label, this.value, this.color);
}
