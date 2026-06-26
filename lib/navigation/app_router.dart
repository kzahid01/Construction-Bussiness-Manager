import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/inventory/inventory_list_screen.dart';
import '../screens/inventory/add_edit_inventory_screen.dart';
import '../screens/projects/projects_list_screen.dart';
import '../screens/projects/project_form_screen.dart';
import '../screens/purchases/purchase_list_screen.dart';
import '../screens/purchases/purchase_form_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/suppliers/suppliers_screen.dart';
import '../services/auth_provider.dart';
import '../utils/constants.dart';

// ─── Route Definitions ────────────────────────────────────────────────────────

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const home = '/home';
  static const inventoryList = '/inventory';
  static const inventoryAdd = '/inventory/add';
  static const projectsList = '/projects';
  static const projectAdd = '/projects/add';
  static const purchasesList = '/purchases';
  static const purchasesAdd = '/purchases/add';
  static const suppliers = '/suppliers';
  static const reports = '/reports';
}

Route<dynamic> generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.home:
      return _fade(const MainNavShell());
    case AppRoutes.inventoryList:
      return _fade(const InventoryListScreen());
    case AppRoutes.inventoryAdd:
      return _slide(const AddEditInventoryScreen());
    case AppRoutes.projectsList:
      return _fade(const ProjectsListScreen());
    case AppRoutes.projectAdd:
      return _slide(const ProjectFormScreen());
    case AppRoutes.purchasesList:
      return _fade(const PurchaseListScreen());
    case AppRoutes.purchasesAdd:
      return _slide(const PurchaseFormScreen());
    case AppRoutes.suppliers:
      return _fade(const SuppliersScreen());
    case AppRoutes.reports:
      return _fade(const ReportsScreen());
    default:
      return _fade(const MainNavShell());
  }
}

PageRoute _fade(Widget page) => PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 200),
    );

PageRoute _slide(Widget page) => PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: FadeTransition(opacity: anim, child: child),
      ),
      transitionDuration: const Duration(milliseconds: 250),
    );

// ─── Profile Avatar Widget (shown on every screen) ───────────────────────────

class ProfileAvatar extends StatelessWidget {
  final double radius;
  const ProfileAvatar({super.key, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showProfileMenu(context),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        backgroundImage: const AssetImage('assets/images/profile.png'),
      ),
    );
  }

  void _showProfileMenu(BuildContext context) {
    final auth = context.read<AuthProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Profile header
            CircleAvatar(
              radius: 45,
              backgroundColor: AppColors.primary,
              backgroundImage: const AssetImage('assets/images/profile.png'),
            ),
            const SizedBox(height: 12),
            Text(
              auth.user?.fullName ?? 'Zahid Bashir',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              auth.user?.email ?? '',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                (auth.user?.role ?? 'admin').toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            // Logout button
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: const Text(
                'Logout',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                auth.logout();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Main Navigation Shell ────────────────────────────────────────────────────

class MainNavShell extends StatefulWidget {
  const MainNavShell({super.key});

  @override
  State<MainNavShell> createState() => _MainNavShellState();
}

class _MainNavShellState extends State<MainNavShell> {
  int _currentIndex = 0;

  static const _tabs = [
    _TabItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard'),
    _TabItem(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: 'Inventory'),
    _TabItem(icon: Icons.construction_outlined, activeIcon: Icons.construction, label: 'Projects'),
    _TabItem(icon: Icons.shopping_cart_outlined, activeIcon: Icons.shopping_cart, label: 'Purchases'),
    _TabItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, label: 'Reports'),
  ];

  static const _tabTitles = [
    'Dashboard',
    'Inventory',
    'Projects',
    'Purchases',
    'Reports',
  ];

  static final _screens = [
    const DashboardScreen(),
    const InventoryListScreen(),
    const ProjectsListScreen(),
    const PurchaseListScreen(),
    const ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Row(
          children: [
            // Profile photo on the LEFT of every screen
            const ProfileAvatar(radius: 18),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tabTitles[_currentIndex],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Zahid Bashir',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 62,
            child: Row(
              children: _tabs.asMap().entries.map((e) {
                final idx = e.key;
                final tab = e.value;
                final selected = _currentIndex == idx;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _currentIndex = idx),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            selected ? tab.activeIcon : tab.icon,
                            key: ValueKey(selected),
                            color: selected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: selected ? 20 : 0,
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
