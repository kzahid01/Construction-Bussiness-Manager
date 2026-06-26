import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/common_widgets.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final _api = ApiService();
  List<Supplier> _suppliers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final suppliers = await _api.getSuppliers();
      if (mounted) {
        setState(() {
          _suppliers = suppliers;
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

  void _openForm([Supplier? supplier]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SupplierForm(
        supplier: supplier,
        onSaved: () {
          Navigator.pop(context);
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suppliers'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorBanner(message: _error!, onRetry: _load)
              : _suppliers.isEmpty
                  ? EmptyState(
                      icon: Icons.store_outlined,
                      title: 'No suppliers yet',
                      subtitle: 'Add your material suppliers',
                      actionLabel: 'Add Supplier',
                      onAction: () => _openForm(),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: _suppliers.length,
                        itemBuilder: (_, i) => _buildCard(_suppliers[i]),
                      ),
                    ),
    );
  }

  Widget _buildCard(Supplier s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                s.name[0].toUpperCase(),
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                if (s.contactPerson != null)
                  Text(s.contactPerson!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Row(children: [
                  if (s.phone != null) ...[
                    const Icon(Icons.phone_outlined,
                        size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(s.phone!,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(width: 12),
                  ],
                  if (s.email != null) ...[
                    const Icon(Icons.email_outlined,
                        size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(s.email!,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ]),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: AppColors.primaryLight, size: 20),
            onPressed: () => _openForm(s),
          ),
        ],
      ),
    );
  }
}

// ─── Supplier Form Bottom Sheet ───────────────────────────────────────────────

class _SupplierForm extends StatefulWidget {
  final Supplier? supplier;
  final VoidCallback onSaved;
  const _SupplierForm({this.supplier, required this.onSaved});

  @override
  State<_SupplierForm> createState() => _SupplierFormState();
}

class _SupplierFormState extends State<_SupplierForm> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _loading = false;

  bool get _isEdit => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final s = widget.supplier!;
      _nameCtrl.text = s.name;
      _contactCtrl.text = s.contactPerson ?? '';
      _phoneCtrl.text = s.phone ?? '';
      _emailCtrl.text = s.email ?? '';
      _addressCtrl.text = s.address ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final body = {
        'name': _nameCtrl.text.trim(),
        if (_contactCtrl.text.isNotEmpty)
          'contact_person': _contactCtrl.text.trim(),
        if (_phoneCtrl.text.isNotEmpty) 'phone': _phoneCtrl.text.trim(),
        if (_emailCtrl.text.isNotEmpty) 'email': _emailCtrl.text.trim(),
        if (_addressCtrl.text.isNotEmpty) 'address': _addressCtrl.text.trim(),
      };
      if (_isEdit) {
        await _api.updateSupplier(widget.supplier!.id, body);
      } else {
        await _api.createSupplier(body);
      }
      widget.onSaved();
    } catch (e) {
      if (mounted) showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(_isEdit ? 'Edit Supplier' : 'New Supplier',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 16),
              AppTextField(
                controller: _nameCtrl,
                label: 'Supplier Name *',
                prefixIcon: Icons.store_outlined,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name required' : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                  controller: _contactCtrl,
                  label: 'Contact Person',
                  prefixIcon: Icons.person_outline),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: AppTextField(
                      controller: _phoneCtrl,
                      label: 'Phone',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                      controller: _emailCtrl,
                      label: 'Email',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress),
                ),
              ]),
              const SizedBox(height: 12),
              AppTextField(
                  controller: _addressCtrl,
                  label: 'Address',
                  prefixIcon: Icons.location_on_outlined,
                  maxLines: 2),
              const SizedBox(height: 20),
              LoadingOverlay(
                isLoading: _loading,
                child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  child: Text(_isEdit ? 'Update Supplier' : 'Add Supplier'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
