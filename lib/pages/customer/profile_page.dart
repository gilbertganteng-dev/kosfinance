// Profil penghuni disimpan di backend Laravel; role tidak pernah dikirim dari klien.
import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/auth_session.dart';
import '../../services/db_sync.dart';
import '../../widgets/widgets.dart';

class ProfilePage extends StatefulWidget {
  final UserAccount user;

  const ProfilePage({super.key, required this.user});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController nameC;
  late final TextEditingController usernameC;
  late final TextEditingController phoneC;
  late final TextEditingController emailC;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    nameC = TextEditingController(text: widget.user.name);
    usernameC = TextEditingController(text: widget.user.username);
    phoneC = TextEditingController(text: widget.user.phone);
    emailC = TextEditingController(text: widget.user.email);
  }

  Future<void> _save() async {
    final name = nameC.text.trim();
    final username = usernameC.text.trim().toLowerCase();
    final phone = phoneC.text.trim();
    final email = emailC.text.trim().toLowerCase();
    if (name.isEmpty || username.length < 3 || email.isEmpty) {
      showMessage(context, 'Nama, username minimal 3 karakter, dan email wajib diisi.');
      return;
    }

    setState(() => _saving = true);
    try {
      final response = await ApiService.put('auth/me', {
        'name': name,
        'username': username,
        'phone': phone,
        'email': email,
      });
      final data = response['data'];
      if (data is! Map) throw const ApiException('Respons profil dari server tidak valid.');
      final updated = AuthSession.userFromJson(Map<String, dynamic>.from(data));

      // Update instance in place agar dashboard dan drawer yang memakai referensi ini langsung konsisten.
      widget.user
        ..id = updated.id
        ..name = updated.name
        ..username = updated.username
        ..phone = updated.phone
        ..email = updated.email
        ..role = updated.role;
      AuthSession.currentUser = widget.user;
      final index = accounts.indexWhere((account) => account.id == updated.id);
      if (index >= 0) accounts[index] = widget.user;
      await DbSync.loadAll();
      if (!mounted) return;
      setState(() {});
      showMessage(context, 'Profil berhasil diperbarui.');
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message);
    } catch (_) {
      if (mounted) showMessage(context, 'Profil gagal diperbarui. Periksa koneksi server.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    nameC.dispose();
    usernameC.dispose();
    phoneC.dispose();
    emailC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = roomOf(widget.user);
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Akun')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const CircleAvatar(
            radius: 44,
            backgroundColor: lightGreen,
            child: Icon(Icons.person, size: 54, color: primaryGreen),
          ),
          const SizedBox(height: 16),
          Center(child: Text(widget.user.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
          const SizedBox(height: 18),
          field(nameC, 'Nama lengkap', Icons.badge_outlined),
          field(usernameC, 'Username', Icons.account_circle_outlined),
          field(phoneC, 'Nomor telepon', Icons.phone_outlined, type: TextInputType.phone),
          field(emailC, 'Email', Icons.email_outlined, type: TextInputType.emailAddress),
          ProfileInfoCard(icon: Icons.home_outlined, title: 'Nomor Kamar', value: room?.number ?? '-'),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
              child: Text(_saving ? 'Menyimpan...' : 'SIMPAN PROFIL'),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Perubahan username dan email divalidasi server. Role akun tidak dapat diubah dari halaman profil.',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
