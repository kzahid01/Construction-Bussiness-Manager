import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/common_widgets.dart';
import 'project_detail_screen.dart';
import 'project_form_screen.dart';

class ProjectsListScreen extends StatefulWidget {
  const ProjectsListScreen({super.key});

  @override
  State<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends State<ProjectsListScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();
  late TabController _tabCtrl;

  static const _statuses = ['all', 'active', 'planning', 'on_hold', 'completed', 'cancelled'];
  List<Project> _projects = [];
  String _selectedStatus = 'all';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _statuses.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) return;
      setState(() => _selectedStatus = _statuses[_tabCtrl.index]);
      _load();
    });
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final projects = await _api.getProjects(
        status: _selectedStatus == 'all' ? null : _selectedStatus,
        search: _searchCtrl.text.isEmpty ? null : _searchCtrl.text,
      );
      if (mounted) setState(() { _projects = projects; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _delete(Project p) async {
    final ok = await showConfirmDialog(context,
        title: 'Delete Project',
        message: 'Delete "${p.name}"? All material usage records will also be removed.');
    if (!ok || !mounted) return;
    try {
      await _api.deleteProject(p.id);
      showSuccess(context, 'Project deleted');
      _load();
    } catch (e) {
      showError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: _statuses.map((s) => Tab(text: s.toUpperCase().replaceAll('_', ' '))).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ProjectFormScreen()));
          _load();
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          _buildSearch(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? ErrorBanner(message: _error!, onRetry: _load)
                    : _projects.isEmpty
                        ? EmptyState(
                            icon: Icons.construction_outlined,
                            title: 'No projects found',
                            subtitle: 'Create your first project to get started',
                            actionLabel: 'Add Project',
                            onAction: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const ProjectFormScreen()))
                                .then((_) => _load()),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                              itemCount: _projects.length,
                              itemBuilder: (_, i) => _buildProjectCard(_projects[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search by name or client...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
          prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.8)),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close, color: Colors.white.withOpacity(0.8)),
                  onPressed: () { _searchCtrl.clear(); _load(); })
              : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.15),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white38)),
        ),
        onSubmitted: (_) => _load(),
      ),
    );
  }

  Widget _buildProjectCard(Project p) {
    final isProfit = p.profit >= 0;
    return GestureDetector(
      onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: p.id)))
          .then((_) => _load()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      overflow: TextOverflow.ellipsis),
                  if (p.clientName != null)
                    Text(p.clientName!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ]),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: p.status),
            ]),
            if (p.address != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(child: Text(p.address!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis)),
              ]),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(children: [
              _ProjStat('Budget', formatPKR(p.budget), AppColors.primary),
              const SizedBox(width: 12),
              _ProjStat('Total Cost', formatPKR(p.totalCost), AppColors.textSecondary),
              const SizedBox(width: 12),
              _ProjStat('Profit', formatPKR(p.profit),
                  isProfit ? AppColors.success : AppColors.danger),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isProfit ? AppColors.success : AppColors.danger).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${p.profitMargin.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: isProfit ? AppColors.success : AppColors.danger)),
              ),
            ]),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              _ActionBtn(Icons.edit_outlined, 'Edit', AppColors.primaryLight, () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ProjectFormScreen(project: p)));
                _load();
              }),
              const SizedBox(width: 8),
              _ActionBtn(Icons.delete_outline, 'Delete', AppColors.danger, () => _delete(p)),
            ]),
          ],
        ),
      ),
    );
  }
}

class _ProjStat extends StatelessWidget {
  final String label; final String value; final Color color;
  const _ProjStat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    ],
  );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _ActionBtn(this.icon, this.label, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    ),
  );
}
