// ============================================================
// PEMBAYARAN (QRIS / Transfer Bank / Hubungi Pemilik)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard (salin nomor rekening) + Uint8List
import 'package:image_picker/image_picker.dart'; // memilih foto dari galeri

import '../../core/core.dart';
import '../../data/data.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class PaymentPage extends StatefulWidget {
  final IuranData iuran; // tagihan yang akan dibayar

  const PaymentPage({super.key, required this.iuran});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String method = 'QRIS'; // metode yang dipilih
  Uint8List? proof; // foto bukti pembayaran
  final senderC = TextEditingController();
  final picker = ImagePicker();

  // Metode selain "Hubungi Pemilik" wajib upload bukti
  bool get needProof => method != 'Hubungi Pemilik';

  // Salin teks ke clipboard
  void copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    showMessage(context, 'Disalin: $text');
  }

  // Pilih foto bukti pembayaran dari galeri
  Future<void> pickProof() async {
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1280);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => proof = bytes);
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
            'SIMULASI UTS — ikon ini bukan kode QRIS yang dapat dipindai. Untuk pembayaran sungguhan, gunakan QRIS resmi milik pengelola. Unggah bukti pembayaran simulasi di bawah.',
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
          subtitle: const Text('Transfer sesuai nominal tagihan, lalu unggah bukti transfer.'),
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

  // Bagian upload bukti pembayaran
  Widget proofSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Bukti Pembayaran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        field(senderC, 'Nama pengirim / pemilik rekening', Icons.person_outline),
        if (proof != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(proof!, height: 220, width: double.infinity, fit: BoxFit.cover),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: pickProof,
          icon: const Icon(Icons.upload_file),
          label: Text(proof == null ? 'Unggah Foto Bukti' : 'Ganti Foto Bukti'),
        ),
      ],
    );
  }

  // Kirim pembayaran -> status jadi "Menunggu Konfirmasi"
  void submit() {
    final i = widget.iuran;

    // Cegah pengiriman ganda / pembayaran yang tidak valid
    if (i.status == stProses) {
      showMessage(context, 'Pembayaran ini sedang menunggu konfirmasi pemilik kos.');
      return;
    }

    if (i.status == stLunas) {
      showMessage(context, 'Tagihan ini sudah dikonfirmasi lunas.');
      return;
    }

    if (i.bookingDeadline != null &&
        DateTime.now().isAfter(i.bookingDeadline!) &&
        i.status != stLunas) {
      showMessage(context, 'Batas pembayaran booking sudah berakhir. Silakan lakukan booking ulang.');
      return;
    }

    // Validasi bukti (kecuali bayar tunai)
    if (needProof) {
      if (proof == null) {
        showMessage(context, 'Unggah foto bukti pembayaran terlebih dahulu.');
        return;
      }
      if (senderC.text.trim().isEmpty) {
        showMessage(context, 'Isi nama pengirim / pemilik rekening.');
        return;
      }
    }

    // Simpan data pembayaran ke tagihan
    i.status = stProses;
    i.paymentMethod = method == 'Hubungi Pemilik' ? 'Tunai (via telepon)' : method;
    i.proofBytes = needProof ? proof : null;
    i.proofSender = needProof ? senderC.text.trim() : null;
    i.rejectNote = null;

    // Semua halaman yang sedang terbuka (termasuk Dashboard Penghuni)
    // langsung mengetahui bahwa status pembayaran berubah.
    notifyDataChanged();

    // Beri tahu admin ada bukti pembayaran baru
    addAdminNotification(
      type: 'payment',
      title: 'Bukti pembayaran baru',
      message: '${i.residentName} mengirim pembayaran ${formatRupiah(i.amount)} untuk kamar ${i.roomNumber}.',
    );

    // Beri konfirmasi ke penghuni sendiri
    addResidentNotification(
      residentName: i.residentName,
      title: 'Pembayaran dikirim',
      message: 'Pembayaran ${formatRupiah(i.amount)} untuk ${i.iuranType} sedang menunggu konfirmasi pemilik kos.',
    );

    showMessage(context, 'Terkirim. Menunggu konfirmasi pemilik kos.');
    Navigator.pop(context);
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
          if (needProof) ...[
            const SizedBox(height: 14),
            proofSection(),
          ],
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: submit,
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
              child: Text(needProof ? 'KIRIM BUKTI PEMBAYARAN' : 'AJUKAN PEMBAYARAN TUNAI'),
            ),
          ),
        ],
      ),
    );
  }
}
