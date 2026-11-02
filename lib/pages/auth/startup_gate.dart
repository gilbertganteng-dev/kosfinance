// ============================================================
// STARTUP GATE: layar singkat saat aplikasi pertama dibuka.
// Memuat data dari database (Laragon), lalu menampilkan halaman Login yang sama seperti sebelumnya.
// ============================================================

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../services/api_config.dart';
import '../../services/auth_session.dart';
import '../../services/db_sync.dart';
import '../pages.dart';

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late Future<void> _boot;

  @override
  void initState() {
    super.initState();
    _boot = _start();
  }

  Future<void> _start() async {
    final restored = await AuthSession.restore();
    if (restored) await DbSync.loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _boot,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && !snapshot.hasError) {
          final user = AuthSession.currentUser;
          if (user == null) return const LoginPage();
          return user.role == 'Admin'
              ? const AdminDashboard()
              : CustomerDashboard(user: user);
        }

        return Scaffold(
          backgroundColor: primaryGreen,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: snapshot.hasError
                  ? Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off, size: 52, color: Colors.red),
                          const SizedBox(height: 12),
                          const Text('Tidak bisa terhubung ke API KosFinance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                          const SizedBox(height: 8),
                          Text('Alamat API: $apiBaseUrl', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => setState(() => _boot = _start()),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Coba Lagi'),
                            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
                          ),
                        ],
                      ),
                    )
                  : const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text('Menghubungkan ke database...', style: TextStyle(color: Colors.white)),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}
