// ============================================================
// LAPOR KERUSAKAN HUNIAN
// Penghuni: pilih kategori (Air, Listrik, AC, Lampu, Lainnya) + tulis alasan.
// Admin: lihat STATISTIK laporan per kategori per bulan, lalu daftar laporan
//        DIKELOMPOKKAN PER KATEGORI (ketuk "Air" -> hanya laporan Air yang muncul, dst.).
// ============================================================

import 'dart:typed_data'; // Uint8List: foto kerusakan

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // memilih foto dari galeri

import '../../core/core.dart';
import '../../data/data.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';
import '../../services/api_service.dart';
import '../../services/db_sync.dart';

class ComplaintsPage extends StatefulWidget {
  final UserAccount? user; // penghuni (null jika admin)
  final bool isAdmin;
  const ComplaintsPage({super.key, this.user, this.isAdmin = false});

  @override
  State<ComplaintsPage> createState() => _ComplaintsPageState();
}

class _ComplaintsPageState extends State<ComplaintsPage> {
  final descriptionC = TextEditingController();
  Uint8List? photoBytes;
  final picker = ImagePicker();
  String? selectedCategory; // kategori yang dipilih penghuni
  bool _submitting = false;
  final Set<int> _updatingIds = {};
  late DateTime selectedMonth; // bulan statistik (admin)

  @override
  void initState() {
    super.initState();
    selectedMonth = DateTime(today.year, today.month);
  }

  // Pilih foto kerusakan (opsional)
  Future<void> pickPhoto() async {
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1280);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) setState(() => photoBytes = bytes);
  }

  // Keluhan dan foto dikirim sebagai multipart ke Laravel.
  Future<void> submitComplaint() async {
    final room = widget.user == null ? null : roomOf(widget.user!);
    if (selectedCategory == null) {
      showMessage(context, 'Pilih kategori kerusakan terlebih dahulu.');
      return;
    }
    if (descriptionC.text.trim().length < 5) {
      showMessage(context, 'Deskripsi keluhan minimal 5 karakter.');
      return;
    }
    if (room == null) {
      showMessage(context, 'Akun ini belum terhubung ke kamar. Hubungi admin.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ApiService.postMultipart(
        'complaints',
        fields: {'category': selectedCategory!, 'description': descriptionC.text.trim()},
        fileBytes: photoBytes,
        fileField: 'photo',
        filename: 'complaint-${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await DbSync.loadAll();
      if (!mounted) return;
      descriptionC.clear();
      setState(() {
        photoBytes = null;
        selectedCategory = null;
      });
      showMessage(context, 'Laporan berhasil dikirim ke pengelola.');
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> updateComplaintStatus(ComplaintData complaint, String uiStatus) async {
    final apiStatus = switch (uiStatus) {
      'Diproses' => 'in_progress',
      'Selesai' => 'resolved',
      'Ditolak' => 'rejected',
      _ => 'open',
    };
    setState(() => _updatingIds.add(complaint.id));
    try {
      await ApiService.patch('complaints/${complaint.id}/status', {'status': apiStatus});
      await DbSync.loadAll();
      if (mounted) setState(() {});
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message);
    } finally {
      if (mounted) setState(() => _updatingIds.remove(complaint.id));
    }
  }

  // ---------- Form laporan (penghuni) ----------
  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ada fasilitas rusak?', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Pilih jenis kerusakan, lalu jelaskan masalahnya. Sertakan foto agar pengelola mudah memeriksa.'),
        const SizedBox(height: 14),
        const Text('1. Pilih kategori', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        // Pilihan kategori berupa chip
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: complaintCategories
              .map((c) => ChoiceChip(
                    avatar: Icon(complaintIcon(c), size: 18, color: selectedCategory == c ? primaryGreen : Colors.grey),
                    label: Text(c),
                    selected: selectedCategory == c,
                    selectedColor: lightGreen,
                    onSelected: (_) => setState(() => selectedCategory = c),
                  ))
              .toList(),
        ),
        const SizedBox(height: 14),
        const Text('2. Tulis alasan / detail', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        // Hint di kolom deskripsi berubah sesuai kategori
        TextField(
          controller: descriptionC,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: selectedCategory == null ? 'Alasan laporan' : 'Alasan laporan ($selectedCategory)',
            hintText: complaintHint(selectedCategory ?? 'Lainnya'),
            alignLabelWithHint: true,
            prefixIcon: const Icon(Icons.edit_note),
          ),
        ),
        const SizedBox(height: 10),
        if (photoBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(photoBytes!, height: 180, fit: BoxFit.cover),
          ),
        OutlinedButton.icon(
          onPressed: pickPhoto,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: Text(photoBytes == null ? 'Tambah Foto (opsional)' : 'Ganti Foto'),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _submitting ? null : submitComplaint,
          icon: const Icon(Icons.send_outlined),
          label: Text(_submitting ? 'Mengirim...' : 'KIRIM LAPORAN'),
          style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
        ),
        const Divider(height: 30),
        const Text('Status Laporan Saya', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ---------- Statistik laporan (admin) ----------
  Widget _stats(List<ComplaintData> monthList, List<DateTime> months) {
    // Hitung jumlah laporan per kategori
    final counts = <String, int>{for (final c in complaintCategories) c: 0};
    for (final c in monthList) {
      counts[c.category] = (counts[c.category] ?? 0) + 1;
    }
    final maxCount = counts.values.fold<int>(0, (a, b) => a > b ? a : b); // skala bar
    final menunggu = monthList.where((c) => c.status == 'Menunggu').length;
    final diproses = monthList.where((c) => c.status == 'Diproses').length;
    final selesai = monthList.where((c) => c.status == 'Selesai').length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Statistik Laporan Penghuni', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            // Pilih bulan statistik (default bulan ini)
            DropdownButtonFormField<DateTime>(
              initialValue: selectedMonth,
              decoration: const InputDecoration(labelText: 'Bulan', prefixIcon: Icon(Icons.calendar_month_outlined)),
              items: months.map((m) => DropdownMenuItem(value: m, child: Text(monthLabel(m)))).toList(),
              onChanged: (v) { if (v != null) setState(() => selectedMonth = v); },
            ),
            const SizedBox(height: 14),
            Text('${monthList.length} laporan pada ${monthLabel(selectedMonth)}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            // Bar jumlah laporan per kategori
            ...complaintCategories.map((cat) {
              final n = counts[cat] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(complaintIcon(cat), size: 20, color: primaryGreen),
                    const SizedBox(width: 8),
                    SizedBox(width: 60, child: Text(cat)),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: maxCount == 0 ? 0 : n / maxCount,
                          minHeight: 12,
                          color: primaryGreen,
                          backgroundColor: lightGreen,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(width: 24, child: Text('$n', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
            // Rekap status penanganan
            Row(
              children: [
                Expanded(child: MiniStat(label: 'Menunggu', value: '$menunggu', color: Colors.orange)),
                const SizedBox(width: 8),
                Expanded(child: MiniStat(label: 'Diproses', value: '$diproses', color: Colors.blue)),
                const SizedBox(width: 8),
                Expanded(child: MiniStat(label: 'Selesai', value: '$selesai', color: Colors.green)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Daftar laporan DIKELOMPOKKAN PER KATEGORI (admin) ----------
  // Satu kartu per kategori (Air, Listrik, AC, Lampu, Lainnya).
  // Ketuk kartu "Air" -> hanya laporan Air yang terbuka, kategori lain tetap rapi tertutup.
  List<Widget> _groupedByCategory(List<ComplaintData> monthList) {
    return complaintCategories.map((cat) {
      // Ambil hanya laporan yang kategorinya sama dengan kartu ini
      final items = monthList.where((c) => c.category == cat).toList();
      final menunggu = items.where((c) => c.status == 'Menunggu').length;
      final hasItems = items.isNotEmpty;

      return Card(
        child: ExpansionTile(
          // key unik per kategori + bulan, supaya status buka/tutup tidak tertukar
          key: PageStorageKey('complaint_${cat}_${selectedMonth.year}_${selectedMonth.month}'),
          enabled: hasItems, // kategori tanpa laporan tidak bisa dibuka
          shape: const Border(),
          collapsedShape: const Border(),
          leading: CircleAvatar(
            backgroundColor: lightGreen,
            child: Icon(complaintIcon(cat), color: primaryGreen),
          ),
          title: Text(cat, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: Text(hasItems ? '${items.length} laporan' : 'Tidak ada laporan'),
          // Lencana oranye = ada laporan yang belum ditangani
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (menunggu > 0) Pill(text: '$menunggu menunggu', color: Colors.orange),
              const SizedBox(width: 6),
              Icon(Icons.expand_more, color: hasItems ? null : Colors.grey.shade400),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          children: items.map(_complaintCard).toList(),
        ),
      );
    }).toList();
  }

  // ---------- Kartu satu laporan ----------
  Widget _complaintCard(ComplaintData c) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.isAdmin ? '${c.residentName} • Kamar ${c.roomNumber}' : 'Laporan • Kamar ${c.roomNumber}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                // Admin bisa ubah status; penghuni hanya melihat (onChanged null = dropdown nonaktif)
                DropdownButton<String>(
                  value: c.status,
                  items: const ['Menunggu', 'Diproses', 'Selesai', 'Ditolak'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: widget.isAdmin && !_updatingIds.contains(c.id)
                      ? (v) { if (v != null) updateComplaintStatus(c, v); }
                      : null,
                ),
              ],
            ),
            // Kategori laporan
            Pill(text: c.category, color: primaryGreen),
            const SizedBox(height: 8),
            Text(c.description),
            const SizedBox(height: 6),
            Text(formatDate(c.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 12)),
            if (c.photoAvailable) ...[
              const SizedBox(height: 10),
              // ValueKey: state foto menempel pada laporannya, bukan pada posisi di daftar
              _ComplaintPhoto(key: ValueKey('complaint_photo_${c.id}'), complaintId: c.id),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final months = List.generate(6, (i) => DateTime(today.year, today.month - i));

    // Admin: laporan pada bulan terpilih. Penghuni: semua laporan miliknya.
    final list = widget.isAdmin
        ? complaints.where((c) => c.createdAt.year == selectedMonth.year && c.createdAt.month == selectedMonth.month).toList()
        : complaints.where((c) => c.residentName == widget.user?.name).toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.isAdmin ? 'Laporan Kerusakan Hunian' : 'Lapor Kerusakan Hunian')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.isAdmin) _stats(list, months) else _form(),
          if (widget.isAdmin) ...[
            const SizedBox(height: 8),
            const Text('Daftar Laporan per Kategori', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            const Text('Ketuk kategori (Air, Listrik, AC, dst.) untuk melihat semua laporannya.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 6),
            // Admin: satu kartu per kategori, isinya hanya laporan kategori itu
            ..._groupedByCategory(list),
          ] else if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 30),
              child: EmptyState(icon: Icons.build_outlined, message: 'Belum ada laporan kerusakan.'),
            )
          else
            // Penghuni: daftar laporan miliknya sendiri (tetap satu daftar biasa)
            ...list.map(_complaintCard),
          if (widget.isAdmin)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Status dapat diubah oleh admin. Jika kerusakan akibat kesalahan penghuni, catat uang ganti rugi di menu Transaksi '
                '(Pemasukan • Ganti Rugi Kerusakan). Biaya perbaikannya dicatat sebagai Pengeluaran • Perbaikan Fasilitas.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// FOTO LAPORAN
// Foto disimpan privat di backend (hanya pemilik laporan & admin yang boleh melihat),
// jadi diambil lewat API saat kartu laporan tampil, bukan dimuat ke semua laporan sekaligus.
// ============================================================

class _ComplaintPhoto extends StatefulWidget {
  final int complaintId;

  const _ComplaintPhoto({super.key, required this.complaintId});

  @override
  State<_ComplaintPhoto> createState() => _ComplaintPhotoState();
}

class _ComplaintPhotoState extends State<_ComplaintPhoto> {
  Uint8List? _bytes;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ComplaintPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.complaintId != widget.complaintId) {
      // build() otomatis dipanggil setelah didUpdateWidget, jadi cukup set field lalu muat ulang.
      _bytes = null;
      _error = null;
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    final id = widget.complaintId;
    try {
      final bytes = await ApiService.getBytes('complaints/$id/photo');
      if (!mounted || id != widget.complaintId) return;
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted || id != widget.complaintId) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  void _retry() {
    setState(() {
      _error = null;
      _loading = true;
    });
    _load();
  }

  void _zoom() {
    final bytes = _bytes;
    if (bytes == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(child: InteractiveViewer(child: Image.memory(bytes))),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
    }
    final bytes = _bytes;
    if (bytes == null) {
      return Row(
        children: [
          const Icon(Icons.broken_image_outlined, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_error ?? 'Foto tidak dapat dimuat.', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          TextButton(onPressed: _retry, child: const Text('Coba lagi')),
        ],
      );
    }
    return GestureDetector(
      onTap: _zoom,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          bytes,
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const SizedBox(
            height: 60,
            child: Center(child: Text('Foto tidak dapat ditampilkan.', style: TextStyle(color: Colors.grey))),
          ),
        ),
      ),
    );
  }
}
