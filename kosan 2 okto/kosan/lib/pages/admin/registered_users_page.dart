// ============================================================
// ADMIN: DAFTAR AKUN PENGHUNI / CALON PENGHUNI
// ============================================================

import 'package:flutter/material.dart';

import '../../data/data.dart';
import '../../widgets/widgets.dart';

class RegisteredUsersPage extends StatelessWidget {
  const RegisteredUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Semua akun non-admin, diurutkan berdasarkan nama
    final users = accounts.where((account) => account.role != 'Admin').toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return Scaffold(
      appBar: AppBar(title: const Text('Akun Terdaftar')),
      body: users.isEmpty
          ? const EmptyState(icon: Icons.people_outline, message: 'Belum ada akun penghuni.')
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final room = roomOf(user);
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text(user.name.isEmpty ? '?' : user.name[0].toUpperCase())),
                    title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Username: ${user.username}\nNo. HP: ${user.phone}\n${room == null ? 'Belum booking kamar' : 'Kamar ${room.number} • ${room.status}'}'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.person_outline),
                  ),
                );
              },
            ),
    );
  }
}
