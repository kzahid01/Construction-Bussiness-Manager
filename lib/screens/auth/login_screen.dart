import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/common_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success =
        await auth.login(_userCtrl.text.trim(), _passCtrl.text.trim());
    if (!mounted) return;
    if (!success) {
      showError(context, auth.error ?? 'Login failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: LoadingOverlay(
          isLoading: auth.isLoading,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // ── Header ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 60, 32, 40),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.domain,
                            size: 44, color: Colors.white),
                      ),
                      const SizedBox(height: 20),
                      const Text('Construction Manager',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('Sign in to your account',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14)),
                    ],
                  ),
                ),
                // ── Form Card ──────────────────────────────────────────────
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 0),
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Welcome Back',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        const Text('Enter your credentials to continue',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 28),
                        AppTextField(
                          controller: _userCtrl,
                          label: 'Username',
                          prefixIcon: Icons.person_outline,
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _passCtrl,
                          label: 'Password',
                          prefixIcon: Icons.lock_outline,
                          obscureText: !_showPassword,
                          suffix: IconButton(
                            icon: Icon(_showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 28),
                        ElevatedButton(
                          onPressed: auth.isLoading ? null : _login,
                          child: const Text('Sign In'),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: const [
                              Text('Demo Credentials',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: AppColors.primary)),
                              SizedBox(height: 8),
                              _CredRow('Admin', 'admin', 'Admin@123'),
                              _CredRow('Manager', 'manager', 'Manager@123'),
                              _CredRow('Worker', 'worker', 'Worker@123'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CredRow extends StatelessWidget {
  final String role;
  final String user;
  final String pass;
  const _CredRow(this.role, this.user, this.pass);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
              width: 60,
              child: Text(role,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary))),
          Text('$user / $pass',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
