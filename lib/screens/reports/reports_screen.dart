import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/common_widgets.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabCtrl;

  // Stock summary
  Map<String, dynamic>? _stockSummary;
  List<StockSummaryItem> _lowStockItems = [];

  // Project profits
  List<Map<String, dynamic>> _projectProfits = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getStockSummary(),
        _api.getLowStock(),
        _api.getProjectProfits(),
      ]);
      if (mounted) {
        setState(() {
          _stockSummary = results[0] as Map<String, dynamic>;
          _lowStockItems = results[1] as List<StockSummaryItem>;
          _projectProfits =
              results[2] as List<Map<String, dynamic>>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'STOCK'),
            Tab(text: 'LOW STOCK'),
            Tab(text: 'PROFIT'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorBanner(message: _error!, onRetry: _load)
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _StockTab(summary: _stockSummary),
                    _LowStockTab(items: _lowStockItems),
                    _ProfitTab(projects: _projectProfits),
                  ],
                ),
    );
  }
}

// ─── Stock Summary Tab ────────────────────────────────────────────────────────

class _StockTab extends StatelessWidget {
  final Map<String, dynamic>? summary;
  const _StockTab({required this.summary});

  @override
  Widget build(BuildContext context) {
    if (summary == null) {
      return const EmptyState(
          icon: Icons.inventory_2_outlined, title: 'No stock data');
    }

    final items = (summary!['items'] as List)
        .map((e) => StockSummaryItem.fromJson(e as Map<String, dynamic>))
        .toList();

    // group by category for chart
    final Map<String, double> catValues = {};
    for (final item in items) {
      final cat = item.categoryName ?? 'Uncategorized';
      catValues[cat] = (catValues[cat] ?? 0) + item.totalValue;
    }

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // KPI Cards
          Row(children: [
            Expanded(
              child: _KpiCard(
                label: 'Total Items',
                value: '${summary!['total_items']}',
                icon: Icons.inventory_2_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                label: 'Total Value',
                value: formatPKR((summary!['total_value'] as num).toDouble()),
                icon: Icons.monetization_on_outlined,
                color: AppColors.success,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _KpiCard(
                label: 'Low Stock',
                value: '${summary!['low_stock_count']}',
                icon: Icons.warning_amber_outlined,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                label: 'Out of Stock',
                value: '${summary!['out_of_stock_count']}',
                icon: Icons.remove_shopping_cart_outlined,
                color: AppColors.danger,
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // Pie chart by category
          if (catValues.isNotEmpty) ...[
            const Text('Value by Category',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            _CategoryPieChart(data: catValues),
            const SizedBox(height: 20),
          ],

          // Item table
          const Text('All Items',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: AppColors.cardShadow,
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.06),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(children: const [
                    Expanded(
                        flex: 3,
                        child: Text('ITEM',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary))),
                    Expanded(
                        flex: 2,
                        child: Text('QTY',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary))),
                    Expanded(
                        flex: 2,
                        child: Text('VALUE',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary))),
                  ]),
                ),
                ...items.asMap().entries.map((e) {
                  final item = e.value;
                  final isLast = e.key == items.length - 1;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: item.isLowStock
                          ? AppColors.danger.withOpacity(0.04)
                          : null,
                      border: isLast
                          ? null
                          : const Border(
                              bottom: BorderSide(color: AppColors.divider)),
                    ),
                    child: Row(children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis),
                            if (item.categoryName != null)
                              Text(item.categoryName!,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${formatNum(item.quantity)} ${item.unit}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: item.isLowStock
                                  ? AppColors.danger
                                  : AppColors.textPrimary),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          formatPKR(item.totalValue),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary),
                        ),
                      ),
                    ]),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Low Stock Tab ────────────────────────────────────────────────────────────

class _LowStockTab extends StatelessWidget {
  final List<StockSummaryItem> items;
  const _LowStockTab({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.check_circle_outline,
        title: 'All stocked up!',
        subtitle: 'No items are below their minimum threshold.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        final pct = item.minQuantity > 0
            ? (item.quantity / item.minQuantity).clamp(0.0, 1.0)
            : 0.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.danger.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.warning_amber,
                    color: AppColors.warning, size: 18),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(item.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14))),
                _AlertBadge(item.quantity == 0 ? 'OUT' : 'LOW',
                    item.quantity == 0 ? AppColors.danger : AppColors.warning),
              ]),
              const SizedBox(height: 4),
              Text('SKU: ${item.sku}  •  ${item.categoryName ?? 'No category'}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Current: ${formatNum(item.quantity)} ${item.unit}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: item.quantity == 0
                                  ? AppColors.danger
                                  : AppColors.warning)),
                      Text(
                          'Minimum: ${formatNum(item.minQuantity)} ${item.unit}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('Need to order',
                      style: TextStyle(
                          fontSize: 10, color: AppColors.textSecondary)),
                  Text(
                      '${formatNum(item.minQuantity - item.quantity)} ${item.unit}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.primary)),
                ]),
              ]),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: AppColors.danger.withOpacity(0.15),
                  color: item.quantity == 0
                      ? AppColors.danger
                      : AppColors.warning,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Profit Tab ───────────────────────────────────────────────────────────────

class _ProfitTab extends StatelessWidget {
  final List<Map<String, dynamic>> projects;
  const _ProfitTab({required this.projects});

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      return const EmptyState(
          icon: Icons.bar_chart_outlined, title: 'No project data yet');
    }

    final totalBudget = projects.fold<double>(
        0, (s, p) => s + (p['budget'] as num).toDouble());
    final totalProfit = projects.fold<double>(
        0, (s, p) => s + (p['profit'] as num).toDouble());
    final totalCost = projects.fold<double>(
        0, (s, p) => s + (p['total_cost'] as num).toDouble());
    final overallMargin =
        totalBudget > 0 ? (totalProfit / totalBudget) * 100 : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // KPI strip
        Row(children: [
          Expanded(
              child: _KpiCard(
                  label: 'Total Budget',
                  value: formatPKR(totalBudget),
                  icon: Icons.account_balance_outlined,
                  color: AppColors.primary)),
          const SizedBox(width: 10),
          Expanded(
              child: _KpiCard(
                  label: 'Total Cost',
                  value: formatPKR(totalCost),
                  icon: Icons.price_check_outlined,
                  color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _KpiCard(
                  label: 'Net Profit',
                  value: formatPKR(totalProfit),
                  icon: Icons.trending_up_outlined,
                  color:
                      totalProfit >= 0 ? AppColors.success : AppColors.danger)),
          const SizedBox(width: 10),
          Expanded(
              child: _KpiCard(
                  label: 'Avg Margin',
                  value: '${overallMargin.toStringAsFixed(1)}%',
                  icon: Icons.percent_outlined,
                  color:
                      overallMargin >= 0 ? AppColors.success : AppColors.danger)),
        ]),
        const SizedBox(height: 20),

        // Bar chart
        if (projects.length > 1) ...[
          const Text('Budget vs Cost per Project',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          _ProfitBarChart(projects: projects),
          const SizedBox(height: 20),
        ],

        // Project cards
        const Text('Project Breakdown',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        ...projects.map((p) => _ProjectProfitCard(p: p)),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ProjectProfitCard extends StatelessWidget {
  final Map<String, dynamic> p;
  const _ProjectProfitCard({required this.p});

  @override
  Widget build(BuildContext context) {
    final profit = (p['profit'] as num).toDouble();
    final margin = (p['profit_margin'] as num).toDouble();
    final isPos = profit >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: Text(p['name'] as String,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                    overflow: TextOverflow.ellipsis)),
            StatusBadge(status: p['status'] as String),
          ]),
          if (p['client_name'] != null)
            Text(p['client_name'] as String,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _ProfitRow(
                    'Budget', (p['budget'] as num).toDouble(), AppColors.primary)),
            Expanded(
                child: _ProfitRow('Material',
                    (p['actual_material_cost'] as num).toDouble(),
                    AppColors.textSecondary)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
                child: _ProfitRow('Labour',
                    (p['labour_cost'] as num).toDouble(),
                    AppColors.textSecondary)),
            Expanded(
                child: _ProfitRow('Other',
                    (p['other_cost'] as num).toDouble(),
                    AppColors.textSecondary)),
          ]),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total Cost',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
                Text(formatPKR((p['total_cost'] as num).toDouble()),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: (isPos ? AppColors.success : AppColors.danger)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(children: [
                  Text(formatPKR(profit),
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color:
                              isPos ? AppColors.success : AppColors.danger)),
                  Text('${margin.toStringAsFixed(1)}% margin',
                      style: TextStyle(
                          fontSize: 10,
                          color:
                              isPos ? AppColors.success : AppColors.danger)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfitRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _ProfitRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary)),
          Text(formatPKR(value),
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      );
}

// ─── Pie Chart ────────────────────────────────────────────────────────────────

class _CategoryPieChart extends StatelessWidget {
  final Map<String, double> data;
  const _CategoryPieChart({required this.data});

  static const _colors = [
    Color(0xFF1B4F72), Color(0xFF2E86C1), Color(0xFFF39C12),
    Color(0xFF27AE60), Color(0xFFE74C3C), Color(0xFF8E44AD),
    Color(0xFF17A589), Color(0xFFD35400), Color(0xFF2C3E50),
  ];

  @override
  Widget build(BuildContext context) {
    final total = data.values.fold<double>(0, (s, v) => s + v);
    final entries = data.entries.toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sections: entries.asMap().entries.map((e) {
                  final idx = e.key;
                  final entry = e.value;
                  final pct = total > 0 ? entry.value / total * 100 : 0.0;
                  return PieChartSectionData(
                    color: _colors[idx % _colors.length],
                    value: entry.value,
                    title: '${pct.toStringAsFixed(0)}%',
                    radius: 70,
                    titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 30,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: entries.asMap().entries.map((e) {
              final color = _colors[e.key % _colors.length];
              return Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                Text(e.value.key,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ]);
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Bar Chart ────────────────────────────────────────────────────────────────

class _ProfitBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> projects;
  const _ProfitBarChart({required this.projects});

  @override
  Widget build(BuildContext context) {
    final displayProjects = projects.take(6).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: displayProjects.fold<double>(0, (m, p) {
              final b = (p['budget'] as num).toDouble();
              return b > m ? b : m;
            }) * 1.2,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final label = rodIndex == 0 ? 'Budget' : 'Cost';
                  return BarTooltipItem(
                    '$label\n${formatPKR(rod.toY)}',
                    const TextStyle(color: Colors.white, fontSize: 10),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 50,
                  getTitlesWidget: (v, _) => Text(
                    v >= 1000000
                        ? '${(v / 1000000).toStringAsFixed(1)}M'
                        : v >= 1000
                            ? '${(v / 1000).toStringAsFixed(0)}K'
                            : v.toStringAsFixed(0),
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textSecondary),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    final idx = v.toInt();
                    if (idx >= displayProjects.length) {
                      return const Text('');
                    }
                    final name =
                        (displayProjects[idx]['name'] as String);
                    return Text(
                      name.length > 6
                          ? '${name.substring(0, 6)}..'
                          : name,
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.textSecondary),
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: AppColors.divider, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            barGroups: displayProjects.asMap().entries.map((e) {
              final p = e.value;
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: (p['budget'] as num).toDouble(),
                    color: AppColors.primary,
                    width: 10,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4)),
                  ),
                  BarChartRodData(
                    toY: (p['total_cost'] as num).toDouble(),
                    color: AppColors.accent,
                    width: 10,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4)),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textSecondary)),
                Text(value,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ]),
      );
}

class _AlertBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _AlertBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      );
}
