// ============================================================
// ADMIN: PERIKSA BUKTI PEMBAYARAN
// ============================================================

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class ProofReviewPage extends StatelessWidget {
  final IuranData iuran;

  const ProofReviewPage({super.key, required this.iuran});

  // Tolak pembayaran + beri alasan ke penghuni
  Future<void> reject(BuildContext context) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak Pembayaran'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(labelText: 'Alasan (mis. nominal tidak sesuai)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tolak')),
        ],
      ),
    );

    if (ok != true) return;
    // Kembalikan status ke Belum Dibayar dan simpan alasan penolakan
    iuran.status = stBelum;
    iuran.rejectNote = c.text.trim().isEmpty ? 'Bukti pembayaran tidak valid.' : c.text.trim();
    iuran.proofBytes = null;
    iuran.proofSender = null;

    addResidentNotification(
      residentName: iuran.residentName,
      title: 'Pembayaran ditolak',
      message: iuran.rejectNote ?? 'Bukti pembayaran perlu diperbaiki.',
    );

    notifyDataChanged();
    if (context.mounted) Navigator.pop(context);
  }

  // Perbesar foto bukti
  void zoom(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(child: Image.memory(iuran.proofBytes!)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Periksa Pembayaran')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Detail pembayaran
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  InfoRow(label: 'Penghuni', value: iuran.residentName),
                  InfoRow(label: 'Kamar', value: iuran.roomNumber),
                  InfoRow(label: 'Nominal tagihan', value: formatRupiah(iuran.amount)),
                  InfoRow(label: 'Metode', value: iuran.paymentMethod ?? '-'),
                  InfoRow(label: 'Nama pengirim', value: iuran.proofSender ?? '-'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Bukti Pembayaran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (iuran.proofBytes != null)
            GestureDetector(
              onTap: () => zoom(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(iuran.proofBytes!, width: double.infinity, fit: BoxFit.fitWidth),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: const Text(
                'Tidak ada foto bukti (pembayaran tunai via telepon atau data contoh). Konfirmasi hanya jika uang sudah diterima.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'Cocokkan nominal, tanggal, dan nama pengirim dengan mutasi rekening / e-wallet sebelum mengonfirmasi.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 18),
          // Tombol tolak / konfirmasi
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => reject(context),
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: const Text('Tolak'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    markPaid(iuran); // tandai lunas + catat pemasukan otomatis
                    showMessage(context, 'Pembayaran ${iuran.residentName} dikonfirmasi.');
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Konfirmasi'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
