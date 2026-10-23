// ============================================================
// PROFIL AKUN (penghuni)
// ============================================================

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class ProfilePage extends StatelessWidget {
  final UserAccount user;

  const ProfilePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final room = roomOf(user);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil Akun')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const CircleAvatar(
            radius: 50,
            backgroundColor: lightGreen,
            child: Icon(Icons.person, size: 60, color: primaryGreen),
          ),
          const SizedBox(height: 20),
          Center(child: Text(user.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
          const SizedBox(height: 20),
          ProfileInfoCard(icon: Icons.person_outline, title: 'Nama', value: user.name),
          ProfileInfoCard(icon: Icons.home_outlined, title: 'Nomor Kamar', value: room?.number ?? '-'),
          ProfileInfoCard(icon: Icons.account_circle_outlined, title: 'Username', value: user.username),
          ProfileInfoCard(icon: Icons.phone_outlined, title: 'Nomor Telepon', value: user.phone),
          if (user.email.isNotEmpty)
            ProfileInfoCard(icon: Icons.email_outlined, title: 'Email', value: user.email),
        ],
      ),
    );
  }
}
