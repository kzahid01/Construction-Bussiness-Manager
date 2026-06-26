import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/common_widgets.dart';
import '../inventory/inventory_list_screen.dart';
import '../projects/projects_list_screen.dart';
import '../reports/reports_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiService();
  DashboardStats? _stats;
  List<Project> _recentProjects = [];
  List<InventoryItem> _lowStockItems = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.getDashboard(),
        _api.getProjects(status: 'active'),
        _api.getInventoryItems(lowStockOnly: true),
      ]);
      if (mounted) {
        setState(() {
          _stats = results[0] as DashboardStats;
          _recentProjects = (results[1] as List<Project>).take(3).toList();
          _lowStockItems = (results[2] as List<InventoryItem>).take(5).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorBanner(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _greeting(user),
                        const SizedBox(height: 20),
                        _statsGrid(),
                        const SizedBox(height: 24),
                        _quickActions(),
                        const SizedBox(height: 24),
                        if (_recentProjects.isNotEmpty) ...[
                          SectionHeader(
                            title: 'Active Projects',
                            actionLabel: 'View All',
                            onAction: () => Navigator.push(context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const ProjectsListScreen())),
                          ),
                          const SizedBox(height: 12),
                          ..._recentProjects.map(_buildProjectCard),
                          const SizedBox(height: 24),
                        ],
                        if (_lowStockItems.isNotEmpty) ...[
                          SectionHeader(
                            title: '⚠️ Low Stock Alerts',
                            actionLabel: 'View All',
                            onAction: () => Navigator.push(context,
                                MaterialPageRoute(
                                    builder: (_) => const InventoryListScreen(
                                        lowStockOnly: true))),
                          ),
                          const SizedBox(height: 12),
                          ..._lowStockItems.map(_buildLowStockCard),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _greeting(User? user) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.15),
          child: Text(
            (user?.fullName.isNotEmpty == true)
                ? user!.fullName[0].toUpperCase()
                : 'U',
            style: const TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hello, ${user?.fullName ?? ''}',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              Text(user?.role.toUpperCase() ?? '',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statsGrid() {
    final s = _stats;
    if (s == null) return const SizedBox();
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        StatCard(
          title: 'Inventory Items',
          value: '${s.totalInventoryItems}',
          icon: Icons.inventory_2_outlined,
          color: AppColors.primary,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const InventoryListScreen())),
        ),
        StatCard(
          title: 'Low Stock',
          value: '${s.lowStockItems}',
          icon: Icons.warning_amber_outlined,
          color: s.lowStockItems > 0 ? AppColors.danger : AppColors.success,
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      const InventoryListScreen(lowStockOnly: true))),
        ),
        StatCard(
          title: 'Active Projects',
          value: '${s.activeProjects}',
          icon: Icons.construction_outlined,
          color: AppColors.accent,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ProjectsListScreen())),
        ),
        StatCard(
          title: 'Stock Value',
          value: formatPKR(s.totalInventoryValue),
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.success,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ReportsScreen())),
        ),
      ],
    );
  }

  Widget _quickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Quick Actions'),
        const SizedBox(height: 12),
        Row(
          children: [
            _QuickActionBtn(
              icon: Icons.add_box_outlined,
              label: 'Add Item',
              color: AppColors.primary,
              onTap: () => Navigator.pushNamed(context, '/inventory/add')
                  .then((_) => _load()),
            ),
            const SizedBox(width: 10),
            _QuickActionBtn(
              icon: Icons.add_business_outlined,
              label: 'New Project',
              color: AppColors.accent,
              onTap: () => Navigator.pushNamed(context, '/projects/add')
                  .then((_) => _load()),
            ),
            const SizedBox(width: 10),
            _QuickActionBtn(
              icon: Icons.shopping_cart_outlined,
              label: 'Purchase',
              color: AppColors.success,
              onTap: () => Navigator.pushNamed(context, '/purchases/add')
                  .then((_) => _load()),
            ),
            const SizedBox(width: 10),
            _QuickActionBtn(
              icon: Icons.bar_chart_outlined,
              label: 'Reports',
              color: Colors.purple,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ReportsScreen())),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProjectCard(Project p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(p.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      overflow: TextOverflow.ellipsis)),
              StatusBadge(status: p.status),
            ],
          ),
          if (p.clientName != null) ...[
            const SizedBox(height: 4),
            Text(p.clientName!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _MiniStat('Budget', formatPKR(p.budget)),
              const SizedBox(width: 16),
              _MiniStat('Profit', formatPKR(p.profit),
                  color: p.profit >= 0 ? AppColors.success : AppColors.danger),
              const SizedBox(width: 16),
              _MiniStat('Margin', '${p.profitMargin.toStringAsFixed(1)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockCard(InventoryItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: AppColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 13)),
                Text(
                    '${formatNum(item.quantity)} ${item.unit} remaining (min: ${formatNum(item.minQuantity)})',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('LOW',
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _MiniStat(this.label, this.value, {this.color});

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
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color ?? AppColors.textPrimary)),
      ],
    );
  }
}
