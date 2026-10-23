// ============================================================
// LUPA PASSWORD
// ============================================================

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../../widgets/widgets.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final userC = TextEditingController();
  final phoneC = TextEditingController();
  final passC = TextEditingController();
  final pass2C = TextEditingController();

  // Verifikasi username + nomor HP, lalu ganti password
  void reset() {
    final user = userC.text.trim().toLowerCase();
    final found = accounts.where((a) => a.username == user && a.phone == phoneC.text.trim());

    if (found.isEmpty) {
      showMessage(context, 'Username atau nomor HP tidak cocok.');
      return;
    }
    if (passC.text.length < 3) {
      showMessage(context, 'Password baru minimal 3 karakter.');
      return;
    }
    if (passC.text != pass2C.text) {
      showMessage(context, 'Konfirmasi password tidak sama.');
      return;
    }

    found.first.password = passC.text; // simpan password baru
    showMessage(context, 'Password berhasil diubah. Silakan login.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lupa Password')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Masukkan username dan nomor HP yang terdaftar untuk verifikasi, lalu buat password baru.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          field(userC, 'Username', Icons.person_outline),
          field(phoneC, 'Nomor HP terdaftar', Icons.phone_outlined, type: TextInputType.phone),
          field(passC, 'Password Baru', Icons.lock_outline, obscure: true),
          field(pass2C, 'Konfirmasi Password Baru', Icons.lock_reset_outlined, obscure: true),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: reset,
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
              child: const Text('UBAH PASSWORD'),
            ),
          ),
        ],
      ),
    );
  }
}
