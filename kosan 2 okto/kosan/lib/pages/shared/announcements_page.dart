// ============================================================
// PENGUMUMAN DAN PERATURAN KOS
// Admin boleh menerbitkan pengumuman; penghuni hanya membaca.
// ============================================================

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class AnnouncementsPage extends StatefulWidget {
  final bool isAdmin;
  const AnnouncementsPage({super.key, this.isAdmin = false});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  final titleC = TextEditingController();
  final bodyC = TextEditingController();

  // Terbitkan pengumuman baru (admin)
  void addAnnouncement() {
    if (titleC.text.trim().isEmpty || bodyC.text.trim().isEmpty) {
      showMessage(context, 'Judul dan isi pengumuman wajib diisi.');
      return;
    }
    announcements.insert(0, AnnouncementData(
      id: DateTime.now().millisecondsSinceEpoch,
      title: titleC.text.trim(),
      body: bodyC.text.trim(),
      createdAt: DateTime.now(),
    ));
    titleC.clear();
    bodyC.clear();
    notifyDataChanged();
    setState(() {});
    showMessage(context, 'Pengumuman berhasil ditambahkan.');
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
              onPressed: addAnnouncement,
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('TERBITKAN'),
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
