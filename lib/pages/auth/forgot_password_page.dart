// Password recovery uses Laravel's password broker. The reset token comes from the
// email link; this screen also allows pasting the token manually during local testing.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/api_service.dart';
import '../../widgets/widgets.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final emailC = TextEditingController();
  final tokenC = TextEditingController();
  final passC = TextEditingController();
  final pass2C = TextEditingController();
  bool _sending = false;
  bool _resetting = false;

  Future<void> sendResetLink() async {
    final email = emailC.text.trim().toLowerCase();
    if (email.isEmpty) {
      showMessage(context, 'Masukkan email yang terdaftar.');
      return;
    }
    setState(() => _sending = true);
    try {
      final response = await ApiService.post('auth/forgot-password', {'email': email});
      if (!mounted) return;
      showMessage(context, (response['message'] ?? 'Jika email terdaftar, instruksi reset akan dikirim.').toString());
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> resetPassword() async {
    final email = emailC.text.trim().toLowerCase();
    if (email.isEmpty || tokenC.text.trim().isEmpty) {
      showMessage(context, 'Email dan token reset wajib diisi.');
      return;
    }
    if (passC.text.length < 8 ||
        !RegExp(r'[A-Za-z]').hasMatch(passC.text) ||
        !RegExp(r'\d').hasMatch(passC.text)) {
      showMessage(context, 'Password minimal 8 karakter serta mengandung huruf dan angka.');
      return;
    }
    if (passC.text != pass2C.text) {
      showMessage(context, 'Konfirmasi password tidak sama.');
      return;
    }

    setState(() => _resetting = true);
    try {
      final response = await ApiService.post('auth/reset-password', {
        'email': email,
        'token': tokenC.text.trim(),
        'password': passC.text,
        'password_confirmation': pass2C.text,
      });
      if (!mounted) return;
      showMessage(context, (response['message'] ?? 'Password berhasil direset. Silakan login.').toString());
      Navigator.pop(context);
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message);
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  void dispose() {
    emailC.dispose();
    tokenC.dispose();
    passC.dispose();
    pass2C.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lupa Password')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Reset password dilakukan melalui email terdaftar. Setelah menerima token reset, masukkan token di bawah ini.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          field(emailC, 'Email terdaftar', Icons.email_outlined, type: TextInputType.emailAddress),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _sending ? null : sendResetLink,
            icon: const Icon(Icons.mark_email_read_outlined),
            label: Text(_sending ? 'Mengirim...' : 'KIRIM LINK RESET'),
          ),
          const Divider(height: 32),
          field(tokenC, 'Token reset dari email', Icons.key_outlined),
          field(passC, 'Password baru', Icons.lock_outline, obscure: true),
          field(pass2C, 'Konfirmasi password baru', Icons.lock_reset_outlined, obscure: true),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _resetting ? null : resetPassword,
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
              child: Text(_resetting ? 'Menyimpan...' : 'RESET PASSWORD'),
            ),
          ),
        ],
      ),
    );
  }
}
