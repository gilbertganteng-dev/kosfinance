// ============================================================
// CUSTOMER DRAWER (menu ringkas penghuni)
// Sengaja dibuat sedikit supaya penghuni tidak bingung (arahan dosen).
// ============================================================

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../../models/models.dart';
import '../pages.dart';

class CustomerDrawer extends StatelessWidget {
  final UserAccount user;

  const CustomerDrawer({super.key, required this.user});

  // Satu baris menu: tutup drawer lalu buka halaman tujuan
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
    final room = roomOf(user);
    final isActive = room?.status == 'Terisi';

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header drawer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
              color: primaryGreen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: primaryGreen, size: 30),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    room == null ? 'Calon Penghuni' : 'Penghuni',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Dashboard'),
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => CustomerDashboard(user: user)),
              ),
            ),
            // Hanya untuk calon penghuni (belum punya kamar / booking)
            if (room == null)
              item(context, Icons.meeting_room_outlined, 'Cek Kamar & Harga', RoomListPage(user: user)),
            item(context, Icons.receipt_long_outlined, 'Iuran & Riwayat', MyIuranPage(user: user)),
            // Hanya untuk penghuni dengan kamar aktif
            if (isActive)
              item(context, Icons.build_outlined, 'Lapor Kerusakan', ComplaintsPage(user: user)),
            item(context, Icons.person_outline, 'Profil Akun', ProfilePage(user: user)),
            const Divider(height: 8),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout'),
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
