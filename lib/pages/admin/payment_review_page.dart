// Admin memeriksa pembayaran yang dinyatakan penghuni, lalu mengonfirmasi atau menolaknya.
// Tidak ada bukti unggahan: cocokkan nominal & metode dengan mutasi rekening / e-wallet / uang tunai.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/db_sync.dart';
import '../../widgets/widgets.dart';

class PaymentReviewPage extends StatefulWidget {
  final IuranData iuran;

  const PaymentReviewPage({super.key, required this.iuran});

  @override
  State<PaymentReviewPage> createState() => _PaymentReviewPageState();
}

class _PaymentReviewPageState extends State<PaymentReviewPage> {
  bool _working = false;

  Future<void> reject() async {
    final reasonC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak Pembayaran'),
        content: TextField(
          controller: reasonC,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Alasan penolakan'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tolak')),
        ],
      ),
    );
    if (ok != true) return;
    final reason = reasonC.text.trim();
    if (reason.isEmpty) {
      if (mounted) showMessage(context, 'Alasan penolakan wajib diisi.');
      return;
    }

    setState(() => _working = true);
    try {
      await ApiService.post('bills/${widget.iuran.id}/reject', {'reason': reason});
      await DbSync.loadAll();
      if (!mounted) return;
      showMessage(context, 'Pembayaran ditolak. Penghuni dapat mengajukan pembayaran lagi.');
      Navigator.pop(context);
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message);
    } finally {
      if (mounted) setState(() => _working = false);
      reasonC.dispose();
    }
  }

  Future<void> confirmPayment() async {
    final confirmed = await confirmAction(
      context,
      'Konfirmasi pembayaran?',
      'Pastikan pembayaran sudah benar-benar diterima sebelum menandai tagihan lunas.',
    );
    if (!confirmed) return;

    setState(() => _working = true);
    try {
      await ApiService.post('bills/${widget.iuran.id}/confirm', const <String, dynamic>{});
      await DbSync.loadAll();
      if (!mounted) return;
      showMessage(context, 'Pembayaran ${widget.iuran.residentName} dikonfirmasi.');
      Navigator.pop(context);
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.iuran;
    return Scaffold(
      appBar: AppBar(title: const Text('Periksa Pembayaran')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  InfoRow(label: 'Penghuni', value: bill.residentName),
                  InfoRow(label: 'Kamar', value: bill.roomNumber),
                  InfoRow(label: 'Jenis tagihan', value: bill.iuranType),
                  InfoRow(label: 'Nominal tagihan', value: formatRupiah(bill.amount)),
                  InfoRow(label: 'Metode', value: bill.paymentMethod ?? '-'),
                  InfoRow(label: 'Jatuh tempo', value: bill.dueDate),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    bill.paymentMethod == 'Tunai (via telepon)'
                        ? 'Pembayaran tunai: konfirmasi hanya setelah uang ${formatRupiah(bill.amount)} benar-benar diterima.'
                        : 'Penghuni menyatakan sudah membayar ${formatRupiah(bill.amount)}. Cocokkan nominal dan waktunya dengan mutasi rekening / e-wallet sebelum mengonfirmasi.',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _working ? null : reject,
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: const Text('Tolak'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _working ? null : confirmPayment,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(_working ? 'Memproses...' : 'Konfirmasi'),
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
