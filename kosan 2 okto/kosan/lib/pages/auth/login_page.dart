// ============================================================
// LOGIN (tanpa pilihan role)
// ============================================================

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../pages.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usernameController = TextEditingController(); // isi kolom username
  final passwordController = TextEditingController(); // isi kolom password
  bool obscurePassword = true; // true = password disembunyikan

  // Proses login: cek username & password, lalu arahkan sesuai role akun
  void login() {
    final u = usernameController.text.trim().toLowerCase();
    final p = passwordController.text;
    final found = accounts.where((a) => a.username == u && a.password == p);

    if (found.isEmpty) {
      showMessage(context, 'Username atau password salah.');
      return;
    }

    final acc = found.first;
    // pushReplacement: halaman login diganti dashboard (tombol back tidak kembali ke login)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => acc.role == 'Admin'
            ? const AdminDashboard()
            : CustomerDashboard(user: acc),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryGreen,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  // Logo aplikasi
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: lightGreen,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(Icons.account_balance_wallet, size: 45, color: primaryGreen), // logo utama kosfinance
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'KosFinance', // untuk nama judul pada halaman utama
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: primaryGreen),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Pencatat Keuangan & Pengelolaan Kos',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 30),
                  // Input username
                  TextField(
                    controller: usernameController,
                    enableSuggestions: false,
                    autocorrect: false,
                    autofillHints: const [],
                    decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline)),
                  ),
                  // Input password (ikon mata untuk tampil/sembunyi)
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    enableSuggestions: false,
                    autocorrect: false,
                    autofillHints: const [],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => obscurePassword = !obscurePassword),
                      ),
                    ),
                  ),
                  // Tombol lupa password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
                      ),
                      child: const Text('Lupa password?'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Tombol login
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('LOGIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Tombol daftar akun baru
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterPage()),
                      ).then((_) {
                        // Setelah kembali dari halaman daftar, kosongkan kolom login
                        if (mounted) {
                          usernameController.clear();
                          passwordController.clear();
                        }
                      }),
                      child: const Text('Daftar Akun Baru'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Pengunjung bisa melihat kamar & harga tanpa login
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RoomListPage()),
                    ),
                    icon: const Icon(Icons.local_offer_outlined),
                    label: const Text('Lihat Kamar & Harga'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
