// ============================================================
// LAPOR KERUSAKAN / KOMPLAIN
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

  // Kirim laporan: wajib pilih kategori + isi alasan
  void submitComplaint() {
    final room = widget.user == null ? null : roomOf(widget.user!);
    if (selectedCategory == null) {
      showMessage(context, 'Pilih kategori kerusakan terlebih dahulu.');
      return;
    }
    if (descriptionC.text.trim().isEmpty) {
      showMessage(context, 'Tuliskan alasan / detail kerusakan terlebih dahulu.');
      return;
    }
    if (room == null) {
      showMessage(context, 'Akun ini belum terhubung ke kamar. Hubungi admin untuk demo.');
      return;
    }
    final category = selectedCategory!;
    // insert(0, ...) = laporan terbaru ditaruh paling atas
    complaints.insert(0, ComplaintData(
      id: DateTime.now().millisecondsSinceEpoch,
      residentName: widget.user!.name,
      roomNumber: room.number,
      category: category,
      description: descriptionC.text.trim(),
      createdAt: DateTime.now(),
      photoBytes: photoBytes,
    ));
    // Admin diberi tahu ada laporan baru
    addAdminNotification(
      type: 'complaint',
      title: 'Laporan kerusakan baru ($category)',
      message: '${widget.user!.name} melaporkan masalah $category di kamar ${room.number}.',
    );
    descriptionC.clear();
    setState(() {
      photoBytes = null;
      selectedCategory = null;
    });
    showMessage(context, 'Laporan berhasil dikirim ke pengelola.');
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
          onPressed: submitComplaint,
          icon: const Icon(Icons.send_outlined),
          label: const Text('KIRIM LAPORAN'),
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
                  items: const ['Menunggu', 'Diproses', 'Selesai'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: widget.isAdmin
                      ? (v) {
                          if (v == null) return;
                          setState(() => c.status = v);
                          notifyDataChanged();
                          // Penghuni diberi tahu status laporannya berubah
                          addResidentNotification(
                            residentName: c.residentName,
                            title: 'Status komplain diperbarui',
                            message: 'Laporan ${c.category} kamu sekarang berstatus $v.',
                          );
                        }
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
            if (c.photoBytes != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(c.photoBytes!, height: 180, width: double.infinity, fit: BoxFit.cover),
              ),
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
      appBar: AppBar(title: Text(widget.isAdmin ? 'Laporan Kerusakan' : 'Lapor Kerusakan / Komplain')),
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
