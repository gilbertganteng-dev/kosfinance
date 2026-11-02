// ============================================================
// IURAN & REMINDER (admin)
// Sudah menggabungkan fitur "Pengingat Jatuh Tempo":
// ringkasan terlambat, keterangan jatuh tempo per tagihan, dan kirim reminder.
// ============================================================

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';
import '../../services/api_service.dart';
import '../../services/db_sync.dart';
import '../pages.dart';

class IuranPage extends StatefulWidget {
  const IuranPage({super.key});

  @override
  State<IuranPage> createState() => _IuranPageState();
}

class _IuranPageState extends State<IuranPage> {
  String filter = 'Semua';

  // Reminder dibuat sebagai notifikasi di backend agar tersimpan lintas perangkat.
  Future<void> remindAll() async {
    final targets = iuranList.where((i) => i.status == stBelum || i.status == stKadaluarsa).toList();
    if (targets.isEmpty) {
      showMessage(context, 'Tidak ada tagihan yang perlu diingatkan.');
      return;
    }
    final ok = await confirmAction(context, 'Kirim reminder?', 'Reminder dikirim ke ${targets.length} tagihan yang belum dibayar.');
    if (!ok) return;
    var sent = 0;
    try {
      for (final bill in targets) {
        await ApiService.post('bills/${bill.id}/remind', const <String, dynamic>{});
        sent++;
      }
      await DbSync.loadAll();
      if (mounted) showMessage(context, 'Reminder dikirim ke $sent tagihan.');
    } on ApiException catch (error) {
      if (mounted) showMessage(context, 'Sebagian reminder terkirim ($sent). ${error.message}');
      await DbSync.loadAll();
    }
  }

  Future<void> _markCashPaid(IuranData bill) async {
    try {
      await ApiService.post('bills/${bill.id}/payments', const {'payment_method': 'cash'});
      await ApiService.post('bills/${bill.id}/confirm', const <String, dynamic>{});
      await DbSync.loadAll();
      if (mounted) showMessage(context, 'Pembayaran tunai dikonfirmasi.');
      if (mounted) setState(() {});
    } on ApiException catch (error) {
      await DbSync.loadAll();
      if (mounted) showMessage(context, error.message);
    }
  }

  Future<void> _unpay(IuranData bill) async {
    final ok = await confirmAction(context, 'Batalkan pembayaran?', 'Sistem akan membuat transaksi pembalik dan memperbarui status kamar bila diperlukan.');
    if (!ok) return;
    try {
      await ApiService.post('bills/${bill.id}/unpay', const <String, dynamic>{});
      await DbSync.loadAll();
      if (mounted) showMessage(context, 'Pembayaran dibatalkan dengan riwayat keuangan tetap tersimpan.');
      if (mounted) setState(() {});
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message);
    }
  }

  // Tombol aksi di tiap kartu sesuai status pembayaran
  Widget statusActions(IuranData iuran) {
    // Menunggu konfirmasi -> admin periksa pembayaran
    if (iuran.status == stProses) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PaymentReviewPage(iuran: iuran)),
            );
            setState(() {});
          },
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Periksa Pembayaran'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
        ),
      );
    }

    // Belum dibayar -> kirim reminder atau tandai dibayar (bayar langsung/tunai)
    if (iuran.status == stBelum) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                try {
                  await ApiService.post('bills/${iuran.id}/remind', const <String, dynamic>{});
                  await DbSync.loadAll();
                  if (mounted) showMessage(context, 'Reminder dikirim ke ${iuran.residentName}.');
                  if (mounted) setState(() {});
                } on ApiException catch (error) {
                  if (mounted) showMessage(context, error.message);
                }
              },
              icon: const Icon(Icons.notifications_none),
              label: const Text('Reminder'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _markCashPaid(iuran),
              child: const Text('Tandai Dibayar'),
            ),
          ),
        ],
      );
    }

    // Expired hanya bisa diingatkan atau diarsipkan; tidak boleh ditandai lunas tanpa pembayaran.
    if (iuran.status == stKadaluarsa) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () async {
            try {
              await ApiService.post('bills/${iuran.id}/remind', const <String, dynamic>{});
              await DbSync.loadAll();
              if (mounted) showMessage(context, 'Reminder dikirim ke ${iuran.residentName}.');
              if (mounted) setState(() {});
            } on ApiException catch (error) {
              if (mounted) showMessage(context, error.message);
            }
          },
          icon: const Icon(Icons.notifications_none),
          label: const Text('Kirim Reminder'),
        ),
      );
    }

    // Hanya tagihan paid yang dapat dibalik melalui ledger.
    if (iuran.status == stLunas) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => _unpay(iuran),
          child: const Text('Tandai Belum Dibayar'),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // Kartu satu tagihan
  Widget iuranCard(IuranData iuran) {
    final overdue = isOverdue(iuran);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor(iuran.status).withValues(alpha: 0.12),
                  child: Icon(Icons.person_outline, color: statusColor(iuran.status)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(iuran.residentName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      Text('Kamar ${iuran.roomNumber}', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                StatusChip(status: iuran.status),
              ],
            ),
            const Divider(height: 24),
            InfoRow(label: 'Jenis Iuran', value: iuran.iuranType),
            InfoRow(label: 'Nominal', value: formatRupiah(iuran.amount)),
            InfoRow(label: 'Jatuh Tempo', value: iuran.dueDate),
            // Keterangan jatuh tempo (fungsi pengingat), merah jika terlambat
            if (iuran.status != stLunas)
              InfoRow(label: 'Keterangan', value: dueLabel(iuran), valueColor: overdue ? Colors.red : null),
            if (iuran.paymentMethod != null)
              InfoRow(label: 'Metode Bayar', value: iuran.paymentMethod!),
            if (iuran.paidAt != null)
              InfoRow(label: 'Tanggal Dibayar', value: formatDate(iuran.paidAt!)),
            const SizedBox(height: 8),
            statusActions(iuran),
            // Edit & hapus tagihan
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Tagihan dikelola backend',
                  onPressed: () => showMessage(context, 'Nominal dan status tagihan dikelola server. Gunakan alur pembayaran atau pembatalan.'),
                  icon: const Icon(Icons.lock_outline),
                ),
                IconButton(
                  tooltip: 'Hapus',
                  onPressed: (iuran.status == stLunas || iuran.status == stProses) ? null : () async {
                    final ok = await confirmAction(context, 'Hapus tagihan?', 'Tagihan yang belum dibayar akan diarsipkan/dihapus tanpa mengubah transaksi pembayaran.');
                    if (!ok) return;
                    try {
                      await ApiService.delete('bills/${iuran.id}');
                      await DbSync.loadAll();
                      if (mounted) showMessage(context, 'Tagihan berhasil dihapus.');
                      if (mounted) setState(() {});
                    } on ApiException catch (error) {
                      if (mounted) showMessage(context, error.message);
                    }
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    // Hitungan ringkasan di bagian atas
    final belum = iuranList.where((i) => i.status == stBelum).length;
    final proses = iuranList.where((i) => i.status == stProses).length;
    final terlambat = iuranList.where(isOverdue).length;

    // Filter + urutan (menunggu konfirmasi & terlambat paling atas)
    final data = (filter == 'Semua' ? List<IuranData>.from(iuranList) : iuranList.where((i) => i.status == filter).toList())
      ..sort((a, b) {
        int p(IuranData x) => x.status == stProses ? 0 : (isOverdue(x) ? 1 : 2);
        if (p(a) != p(b)) return p(a).compareTo(p(b));
        return b.id.compareTo(a.id);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Iuran & Reminder')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Ringkasan status tagihan
          Row(
            children: [
              Expanded(child: MiniStat(label: 'Belum Bayar', value: '$belum', color: Colors.orange)),
              const SizedBox(width: 8),
              Expanded(child: MiniStat(label: 'Konfirmasi', value: '$proses', color: Colors.blue)),
              const SizedBox(width: 8),
              Expanded(child: MiniStat(label: 'Terlambat', value: '$terlambat', color: Colors.red)),
            ],
          ),
          const SizedBox(height: 12),
          // Filter status
          DropdownButtonFormField<String>(
            initialValue: filter,
            decoration: const InputDecoration(labelText: 'Filter Status'),
            items: const ['Semua', stBelum, stProses, stLunas, stKadaluarsa]
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => filter = v!),
          ),
          const SizedBox(height: 8),
          // Reminder massal
          OutlinedButton.icon(
            onPressed: remindAll,
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Kirim reminder ke semua yang belum bayar'),
          ),
          const SizedBox(height: 6),
          const Text(
            'Penghuni yang datang membayar langsung: tekan "Tandai Dibayar", otomatis tercatat sebagai pemasukan.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          if (data.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: EmptyState(icon: Icons.people_outline, message: 'Tidak ada data iuran.'),
            )
          else
            ...data.map(iuranCard),
        ],
      ),
      // Tambah tagihan manual
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const IuranFormPage()),
          );
          setState(() {});
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
