import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/common_widgets.dart';

class ProjectFormScreen extends StatefulWidget {
  final Project? project;
  const ProjectFormScreen({super.key, this.project});

  @override
  State<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends State<ProjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  final _nameCtrl = TextEditingController();
  final _clientCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _estCostCtrl = TextEditingController();
  final _labourCtrl = TextEditingController();
  final _otherCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _status = 'planning';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _loading = false;

  bool get _isEdit => widget.project != null;

  static const _statuses = [
    'planning', 'active', 'on_hold', 'completed', 'cancelled'
  ];

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final p = widget.project!;
      _nameCtrl.text = p.name;
      _clientCtrl.text = p.clientName ?? '';
      _phoneCtrl.text = p.clientPhone ?? '';
      _addressCtrl.text = p.address ?? '';
      _budgetCtrl.text = p.budget.toStringAsFixed(0);
      _estCostCtrl.text = p.estimatedCost.toStringAsFixed(0);
      _labourCtrl.text = p.labourCost.toStringAsFixed(0);
      _otherCtrl.text = p.otherCost.toStringAsFixed(0);
      _descCtrl.text = p.description ?? '';
      _status = p.status;
      _startDate = p.startDate;
      _endDate = p.endDate;
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _clientCtrl, _phoneCtrl, _addressCtrl,
      _budgetCtrl, _estCostCtrl, _labourCtrl, _otherCtrl, _descCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final d = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d != null) setState(() => isStart ? _startDate = d : _endDate = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final body = {
        'name': _nameCtrl.text.trim(),
        if (_clientCtrl.text.isNotEmpty) 'client_name': _clientCtrl.text.trim(),
        if (_phoneCtrl.text.isNotEmpty) 'client_phone': _phoneCtrl.text.trim(),
        if (_addressCtrl.text.isNotEmpty) 'address': _addressCtrl.text.trim(),
        'status': _status,
        'budget': double.tryParse(_budgetCtrl.text) ?? 0.0,
        'estimated_cost': double.tryParse(_estCostCtrl.text) ?? 0.0,
        'labour_cost': double.tryParse(_labourCtrl.text) ?? 0.0,
        'other_cost': double.tryParse(_otherCtrl.text) ?? 0.0,
        if (_descCtrl.text.isNotEmpty) 'description': _descCtrl.text.trim(),
        if (_startDate != null) 'start_date': _startDate!.toIso8601String(),
        if (_endDate != null) 'end_date': _endDate!.toIso8601String(),
      };
      if (_isEdit) {
        await _api.updateProject(widget.project!.id, body);
        if (mounted) showSuccess(context, 'Project updated');
      } else {
        await _api.createProject(body);
        if (mounted) showSuccess(context, 'Project created');
      }
      if (mounted) Navigator.pop(context, true);
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
        title: Text(_isEdit ? 'Edit Project' : 'New Project'),
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _save,
              child: const Text('SAVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _loading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('Project Details'),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _nameCtrl,
                  label: 'Project Name *',
                  prefixIcon: Icons.construction_outlined,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(
                    labelText: 'Project Status',
                    prefixIcon: Icon(Icons.flag_outlined, size: 20),
                  ),
                  items: _statuses.map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) { if (v != null) setState(() => _status = v); },
                ),
                const SizedBox(height: 24),
                _label('Client Information'),
                const SizedBox(height: 12),
                AppTextField(controller: _clientCtrl, label: 'Client Name', prefixIcon: Icons.person_outline),
                const SizedBox(height: 12),
                AppTextField(controller: _phoneCtrl, label: 'Client Phone',
                    prefixIcon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                AppTextField(controller: _addressCtrl, label: 'Project Address',
                    prefixIcon: Icons.location_on_outlined, maxLines: 2),
                const SizedBox(height: 24),
                _label('Schedule'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _DateField(
                    label: 'Start Date',
                    date: _startDate,
                    onTap: () => _pickDate(true),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _DateField(
                    label: 'End Date',
                    date: _endDate,
                    onTap: () => _pickDate(false),
                  )),
                ]),
                const SizedBox(height: 24),
                _label('Financials (PKR)'),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _budgetCtrl,
                  label: 'Contract Budget',
                  prefixIcon: Icons.account_balance_wallet_outlined,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => (v != null && v.isNotEmpty && double.tryParse(v) == null)
                      ? 'Invalid amount' : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _estCostCtrl,
                  label: 'Estimated Cost',
                  prefixIcon: Icons.calculate_outlined,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: AppTextField(
                    controller: _labourCtrl,
                    label: 'Labour Cost',
                    prefixIcon: Icons.people_outline,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: AppTextField(
                    controller: _otherCtrl,
                    label: 'Other Cost',
                    prefixIcon: Icons.more_horiz,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  )),
                ]),
                const SizedBox(height: 24),
                _label('Notes'),
                const SizedBox(height: 12),
                AppTextField(controller: _descCtrl, label: 'Description / Notes',
                    prefixIcon: Icons.notes_outlined, maxLines: 3),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _loading ? null : _save,
                  child: Text(_isEdit ? 'Update Project' : 'Create Project'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t, style: const TextStyle(
      fontSize: 13, fontWeight: FontWeight.w700,
      color: AppColors.textSecondary, letterSpacing: 0.5));
}

class _DateField extends StatelessWidget {
  final String label; final DateTime? date; final VoidCallback onTap;
  const _DateField({required this.label, required this.date, required this.onTap});

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(children: [
        const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(date != null ? _fmt(date!) : 'Not set',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                  color: date != null ? AppColors.textPrimary : AppColors.textSecondary)),
        ]),
      ]),
    ),
  );
}
