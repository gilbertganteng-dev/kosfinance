// ============================================================
// REGISTRASI AKUN
// ============================================================

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/api_service.dart';
import '../../services/auth_session.dart';
import '../../services/db_sync.dart';
import '../../widgets/widgets.dart';
import '../pages.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameC = TextEditingController();
  final userC = TextEditingController();
  final phoneC = TextEditingController();
  final emailC = TextEditingController();
  final passC = TextEditingController();
  final pass2C = TextEditingController();
  bool _loading = false;

  // Registrasi dilakukan di server; role selalu ditentukan backend sebagai resident.
  Future<void> register() async {
    final name = nameC.text.trim();
    final user = userC.text.trim().toLowerCase();
    final phone = phoneC.text.trim();
    final email = emailC.text.trim().toLowerCase();

    // 1. Kolom wajib tidak boleh kosong
    if (name.isEmpty || user.isEmpty || phone.isEmpty || email.isEmpty || passC.text.isEmpty) {
      showMessage(context, 'Nama, username, no. HP, email, dan password wajib diisi.');
      return;
    }
    if (passC.text.length < 8 || !RegExp(r'[A-Za-z]').hasMatch(passC.text) || !RegExp(r'\d').hasMatch(passC.text)) {
      showMessage(context, 'Password minimal 8 karakter dan harus mengandung huruf serta angka.');
      return;
    }
    if (passC.text != pass2C.text) {
      showMessage(context, 'Konfirmasi password tidak sama.');
      return;
    }
    setState(() => _loading = true);
    try {
      final response = await ApiService.post('auth/register', {
        'username': user,
        'name': name,
        'phone': phone,
        'email': email,
        'password': passC.text,
        'password_confirmation': pass2C.text,
      });
      final payload = response['data'];
      if (payload is! Map) {
        throw const ApiException('Respons registrasi dari server tidak valid.');
      }
      await AuthSession.saveSession(Map<String, dynamic>.from(payload));
      await DbSync.loadAll();
      if (!mounted) return;
      final account = AuthSession.currentUser!;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => account.role == 'Admin'
              ? const AdminDashboard()
              : CustomerDashboard(user: account),
        ),
        (_) => false,
      );
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrasi Akun')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          field(nameC, 'Nama Lengkap', Icons.badge_outlined),
          field(userC, 'Username', Icons.person_outline),
          field(phoneC, 'Nomor HP', Icons.phone_outlined, type: TextInputType.phone),
          field(emailC, 'Email', Icons.email_outlined, type: TextInputType.emailAddress),
          field(passC, 'Password', Icons.lock_outline, obscure: true),
          field(pass2C, 'Konfirmasi Password', Icons.lock_reset_outlined, obscure: true),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : register,
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('DAFTAR'),
            ),
          ),
        ],
      ),
    );
  }
}
