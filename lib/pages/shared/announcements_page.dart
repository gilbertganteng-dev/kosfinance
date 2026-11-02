// ============================================================
// PENGUMUMAN DAN PERATURAN KOS
// Admin boleh menerbitkan pengumuman; penghuni hanya membaca.
// ============================================================

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../../widgets/widgets.dart';
import '../../services/api_service.dart';
import '../../services/db_sync.dart';

class AnnouncementsPage extends StatefulWidget {
  final bool isAdmin;
  const AnnouncementsPage({super.key, this.isAdmin = false});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  final titleC = TextEditingController();
  final bodyC = TextEditingController();
  bool _saving = false;

  // Terbitkan pengumuman baru (admin)
  Future<void> addAnnouncement() async {
    if (titleC.text.trim().isEmpty || bodyC.text.trim().isEmpty) {
      showMessage(context, 'Judul dan isi pengumuman wajib diisi.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService.post('announcements', {
        'title': titleC.text.trim(),
        'body': bodyC.text.trim(),
      });
      await DbSync.loadAll();
      if (!mounted) return;
      titleC.clear();
      bodyC.clear();
      setState(() {});
      showMessage(context, 'Pengumuman berhasil diterbitkan.');
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengumuman & Peraturan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Form pengumuman (hanya admin)
          if (widget.isAdmin) ...[
            const Text('Buat pengumuman baru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Judul pengumuman')),
            const SizedBox(height: 10),
            TextField(controller: bodyC, maxLines: 3, decoration: const InputDecoration(labelText: 'Isi pengumuman / peraturan')),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _saving ? null : addAnnouncement,
              icon: const Icon(Icons.campaign_outlined),
              label: Text(_saving ? 'Menerbitkan...' : 'TERBITKAN'),
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
            ),
            const Divider(height: 30),
          ],
          // Daftar pengumuman
          if (announcements.isEmpty)
            const EmptyState(icon: Icons.campaign_outlined, message: 'Belum ada pengumuman.')
          else
            ...announcements.map((a) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.campaign_outlined, color: primaryGreen),
                        const SizedBox(width: 8),
                        Expanded(child: Text(a.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(a.body),
                    const SizedBox(height: 8),
                    Text(formatDate(a.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            )),
        ],
      ),
    );
  }
}
