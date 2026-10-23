// ============================================================
// ADMIN DRAWER (menu samping admin)
// Menu admin memang lebih banyak karena admin mengelola semua data.
// ============================================================

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../pages.dart';

class AdminDrawer extends StatelessWidget {
  const AdminDrawer({super.key});

  // Satu baris menu yang membuka halaman tertentu.
  // Drawer ditutup dulu (pop) lalu halaman dibuka (push), supaya drawer tidak tertinggal terbuka.
  Widget item(BuildContext context, IconData icon, String title, Widget page) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        final nav = Navigator.of(context);
        nav.pop();
        nav.push(MaterialPageRoute(builder: (context) => page));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header drawer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 25, 20, 25),
              color: primaryGreen,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.account_balance_wallet, color: primaryGreen, size: 30),
                  ),
                  SizedBox(height: 14),
                  Text('KosFinance', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  SizedBox(height: 3),
                  Text('Admin / Pengelola', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Dashboard'),
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AdminDashboard()),
              ),
            ),
            item(context, Icons.meeting_room_outlined, 'Kamar & Penghuni', const AdminRoomPage()),
            item(context, Icons.people_alt_outlined, 'Akun Terdaftar', const RegisteredUsersPage()),
            // Pengingat jatuh tempo sudah digabung ke menu Iuran
            item(context, Icons.notifications_none, 'Iuran & Reminder', const IuranPage()),
            // Pemasukan & pengeluaran (listrik, wifi, penjaga, dll.)
            item(context, Icons.receipt_long_outlined, 'Transaksi', const TransactionPage()),
            item(context, Icons.bar_chart_outlined, 'Laporan Keuangan', const ReportPage()),
            // Admin bisa EDIT tipe kamar & harga di sini
            item(context, Icons.local_offer_outlined, 'Kamar & Harga (Edit)', const RoomListPage(isAdmin: true)),
            item(context, Icons.build_outlined, 'Laporan Kerusakan', const ComplaintsPage(isAdmin: true)),
            item(context, Icons.campaign_outlined, 'Pengumuman & Peraturan', const AnnouncementsPage(isAdmin: true)),
            const Divider(height: 8),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout'),
              // pushAndRemoveUntil: hapus semua halaman sebelumnya, kembali ke login
              onTap: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
