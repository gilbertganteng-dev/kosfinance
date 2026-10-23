// ============================================================
// REGISTRASI AKUN
// ============================================================

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

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

  // Validasi form lalu simpan akun baru
  void register() {
    final name = nameC.text.trim();
    final user = userC.text.trim().toLowerCase();
    final phone = phoneC.text.trim();

    // 1. Kolom wajib tidak boleh kosong
    if (name.isEmpty || user.isEmpty || phone.isEmpty || passC.text.isEmpty) {
      showMessage(context, 'Nama, username, no. HP, dan password wajib diisi.');
      return;
    }
    if (passC.text.length < 3) {
      showMessage(context, 'Password minimal 3 karakter.');
      return;
    }
    if (passC.text != pass2C.text) {
      showMessage(context, 'Konfirmasi password tidak sama.');
      return;
    }
    // 2. Username harus unik
    if (accounts.any((a) => a.username == user)) {
      showMessage(context, 'Username sudah dipakai.');
      return;
    }
    // 3. Nama juga harus unik, karena nama dipakai untuk mengaitkan kamar & tagihan ke akun
    if (accounts.any((a) => a.name.toLowerCase() == name.toLowerCase())) {
      showMessage(context, 'Nama sudah terdaftar. Gunakan nama lain agar kamar & tagihan tidak tertukar.');
      return;
    }

    accounts.add(UserAccount(
      username: user,
      password: passC.text,
      name: name,
      phone: phone,
      email: emailC.text.trim(),
    ));
    // Admin diberi tahu ada akun baru
    addAdminNotification( // ada notifikasi baru akun penghuni dibuat
      type: 'account',
      title: 'Pendaftaran akun baru',
      message: '$name baru saja membuat akun penghuni.',
    );

    showMessage(context, 'Registrasi berhasil. Silakan login.');
    Navigator.pop(context); // kembali ke halaman login
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
          field(emailC, 'Email (opsional)', Icons.email_outlined, type: TextInputType.emailAddress),
          field(passC, 'Password', Icons.lock_outline, obscure: true),
          field(pass2C, 'Konfirmasi Password', Icons.lock_reset_outlined, obscure: true),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: register,
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
              child: const Text('DAFTAR'),
            ),
          ),
        ],
      ),
    );
  }
}
