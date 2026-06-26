import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/common_widgets.dart';
import 'purchase_form_screen.dart';

class PurchaseListScreen extends StatefulWidget {
  const PurchaseListScreen({super.key});

  @override
  State<PurchaseListScreen> createState() => _PurchaseListScreenState();
}

class _PurchaseListScreenState extends State<PurchaseListScreen> {
  final _api = ApiService();
  List<Purchase> _purchases = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final purchases = await _api.getPurchases();
      if (mounted) setState(() { _purchases = purchases; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSpend = _purchases.fold<double>(0, (s, p) => s + p.totalAmount);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchases'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PurchaseFormScreen()));
          _load();
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorBanner(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    // Summary Banner
                    Container(
                      color: AppColors.primary,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(children: [
                        _SummaryChip('Total Purchases', '${_purchases.length}'),
                        const SizedBox(width: 16),
                        _SummaryChip('Total Spend', formatPKR(totalSpend)),
                      ]),
                    ),
                    Expanded(
                      child: _purchases.isEmpty
                          ? EmptyState(
                              icon: Icons.shopping_cart_outlined,
                              title: 'No purchases yet',
                              subtitle: 'Record your first material purchase',
                              actionLabel: 'Add Purchase',
                              onAction: () => Navigator.push(context,
                                      MaterialPageRoute(builder: (_) => const PurchaseFormScreen()))
                                  .then((_) => _load()),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                                itemCount: _purchases.length,
                                itemBuilder: (_, i) => _buildCard(_purchases[i]),
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildCard(Purchase p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(p.purchaseNumber,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
            StatusBadge(status: p.status),
          ]),
          const SizedBox(height: 4),
          if (p.supplier != null)
            Text(p.supplier!.name,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(_fmtDate(p.purchaseDate),
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const Spacer(),
            Text(formatPKR(p.totalAmount),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ]),
        ),
        children: [
          if (p.invoiceReference != null)
            _MetaRow(Icons.receipt_outlined, 'Invoice', p.invoiceReference!),
          if (p.notes != null)
            _MetaRow(Icons.notes_outlined, 'Notes', p.notes!),
          if (p.items.isNotEmpty) ...[
            const Divider(height: 16),
            const Text('Items', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12,
                color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            ...p.items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                const Icon(Icons.fiber_manual_record, size: 6, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(child: Text(item.inventoryItem?.name ?? 'Item #${item.inventoryItemId}',
                    style: const TextStyle(fontSize: 12))),
                Text('${formatNum(item.quantity)} × ${formatPKR(item.unitCost)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(width: 8),
                Text(formatPKR(item.totalCost),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              ]),
            )),
          ],
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
}

class _SummaryChip extends StatelessWidget {
  final String label; final String value;
  const _SummaryChip(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7))),
      Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
    ],
  );
}

class _MetaRow extends StatelessWidget {
  final IconData icon; final String label; final String value;
  const _MetaRow(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Icon(icon, size: 14, color: AppColors.textSecondary),
      const SizedBox(width: 6),
      Text('$label: ', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
    ]),
  );
}
