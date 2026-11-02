// ============================================================
// PEMBAYARAN (QRIS / Transfer Bank / Hubungi Pemilik)
// Penghuni membayar di luar aplikasi, lalu menekan "Saya sudah membayar".
// Tidak ada unggah bukti: pemilik kos memverifikasi (mutasi rekening / uang tunai)
// dan menekan konfirmasi atau tolak di halaman admin.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard (salin nomor rekening)

import '../../core/core.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/db_sync.dart';

class PaymentPage extends StatefulWidget {
  final IuranData iuran; // tagihan yang akan dibayar

  const PaymentPage({super.key, required this.iuran});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String method = 'QRIS'; // metode yang dipilih
  bool _submitting = false;

  bool get isCash => method == 'Hubungi Pemilik';

  // Salin teks ke clipboard
  void copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    showMessage(context, 'Disalin: $text');
  }

  // Panel informasi sesuai metode yang dipilih
  Widget methodPanel() {
    if (method == 'QRIS') {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code_2, size: 150, color: Colors.grey),
                SizedBox(height: 8),
                Text('QRIS SIMULASI', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'SIMULASI UTS — ikon ini bukan kode QRIS yang dapat dipindai. Untuk pembayaran sungguhan, gunakan QRIS resmi milik pengelola. Setelah membayar, tekan tombol di bawah.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w500),
          ),
        ],
      );
    }

    if (method == 'Transfer Bank') {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.account_balance, color: primaryGreen),
          title: const Text(bankInfo, style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Transfer sesuai nominal tagihan, lalu tekan tombol di bawah. Pemilik akan mencocokkannya dengan mutasi rekening.'),
          trailing: IconButton(icon: const Icon(Icons.copy), onPressed: () => copy('1234567890')),
        ),
      );
    }

    // Metode "Hubungi Pemilik" (bayar tunai)
    return Card(
      child: ListTile(
        leading: const Icon(Icons.phone_in_talk, color: primaryGreen),
        title: const Text(ownerPhone, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Hubungi pemilik kos via telepon/WhatsApp untuk bayar tunai. Pemilik akan mengonfirmasi setelah uang diterima.'),
        trailing: IconButton(icon: const Icon(Icons.copy), onPressed: () => copy(ownerPhone)),
      ),
    );
  }

  // Menyatakan tagihan sudah dibayar. Tanpa berkas: hanya metode pembayaran yang dikirim ke Laravel.
  Future<void> submit() async {
    final bill = widget.iuran;
    if (bill.status == stProses) {
      showMessage(context, 'Pembayaran ini sedang menunggu konfirmasi pemilik kos.');
      return;
    }
    if (bill.status == stLunas) {
      showMessage(context, 'Tagihan ini sudah dikonfirmasi lunas.');
      return;
    }
    if (bill.bookingDeadline != null && DateTime.now().isAfter(bill.bookingDeadline!)) {
      showMessage(context, 'Batas pembayaran booking sudah berakhir. Silakan hubungi admin.');
      return;
    }

    final ok = await confirmAction(
      context,
      isCash ? 'Ajukan pembayaran tunai?' : 'Sudah melakukan pembayaran?',
      isCash
          ? 'Pemilik kos akan mengonfirmasi setelah uang ${formatRupiah(bill.amount)} diterima langsung.'
          : 'Pastikan Anda sudah membayar ${formatRupiah(bill.amount)} lewat $method. Pemilik kos akan memverifikasinya sebelum tagihan dinyatakan lunas.',
    );
    if (!ok || !mounted) return;

    setState(() => _submitting = true);
    final paymentMethod = switch (method) {
      'Transfer Bank' => 'bank_transfer',
      'Hubungi Pemilik' => 'cash',
      _ => 'ewallet',
    };
    try {
      await ApiService.post('bills/${bill.id}/payments', {'payment_method': paymentMethod});
      await DbSync.loadAll();
      if (!mounted) return;
      showMessage(context, 'Pembayaran diajukan. Menunggu konfirmasi pengelola.');
      Navigator.pop(context);
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final iuran = widget.iuran;

    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran Iuran')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Total tagihan
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Total Tagihan', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                    formatRupiah(iuran.amount),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryGreen),
                  ),
                  const SizedBox(height: 4),
                  Text('${iuran.iuranType} • Kamar ${iuran.roomNumber}'),
                  const SizedBox(height: 4),
                  const Text('Pembayaran harus lunas 100% (tidak bisa dicicil).', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Pilih metode pembayaran
          const Text('Pilih Metode Pembayaran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['QRIS', 'Transfer Bank', 'Hubungi Pemilik']
                .map((m) => ChoiceChip(
                      label: Text(m),
                      selected: method == m,
                      selectedColor: lightGreen,
                      onSelected: (_) => setState(() => method = m),
                    ))
                .toList(),
          ),
          const SizedBox(height: 14),
          methodPanel(),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting ? null : submit,
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
              child: Text(_submitting ? 'Mengirim...' : (isCash ? 'AJUKAN PEMBAYARAN TUNAI' : 'SAYA SUDAH MEMBAYAR')),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Status tagihan menjadi "Menunggu Konfirmasi" sampai pemilik kos memverifikasi pembayaran Anda.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
