// ============================================================
// INVOICE / KUITANSI PDF
// ============================================================

import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw; // membuat dokumen PDF (kuitansi)
import 'package:printing/printing.dart'; // dialog cetak / unduh PDF

import '../../core/core.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class InvoicePage extends StatelessWidget {
  final UserAccount user;
  final IuranData iuran;
  const InvoicePage({super.key, required this.user, required this.iuran});

  // Membuat PDF kuitansi lalu membuka dialog cetak/unduh
  Future<void> downloadInvoice(BuildContext context) async {
    final doc = pw.Document(); // dokumen PDF kosong
    doc.addPage(pw.Page(
      build: (context) => pw.Padding(
        padding: const pw.EdgeInsets.all(24),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('KUITANSI PEMBAYARAN KOS', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text('KosFinance'),
            pw.Divider(),
            pw.Text('Nama penghuni: ${user.name}'),
            pw.Text('Nomor kamar: ${iuran.roomNumber}'),
            pw.Text('Jenis pembayaran: ${iuran.iuranType}'),
            pw.Text('Tanggal jatuh tempo: ${iuran.dueDate}'),
            pw.Text('Tanggal pembayaran: ${iuran.paidAt == null ? '-' : formatDate(iuran.paidAt!)}'),
            pw.Text('Metode pembayaran: ${iuran.paymentMethod ?? '-'}'),
            pw.SizedBox(height: 12),
            pw.Text('Total dibayar: ${formatRupiah(iuran.amount)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Text('Status: LUNAS'),
            pw.SizedBox(height: 30),
            pw.Text('Terima kasih telah melakukan pembayaran.'),
            pw.SizedBox(height: 10),
            pw.Text('Invoice demo dibuat oleh aplikasi KosFinance.'),
          ],
        ),
      ),
    ));
    await Printing.layoutPdf(onLayout: (_) async => doc.save(), name: 'Kuitansi_KosFinance_${user.username}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kuitansi / Invoice')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.receipt_long, color: primaryGreen, size: 64),
          const SizedBox(height: 12),
          const Center(child: Text('KUITANSI PEMBAYARAN', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          const Divider(height: 30),
          InfoRow(label: 'Nama penghuni', value: user.name),
          InfoRow(label: 'Nomor kamar', value: iuran.roomNumber),
          InfoRow(label: 'Jenis pembayaran', value: iuran.iuranType),
          InfoRow(label: 'Tanggal pembayaran', value: iuran.paidAt == null ? '-' : formatDate(iuran.paidAt!)),
          InfoRow(label: 'Metode pembayaran', value: iuran.paymentMethod ?? '-'),
          InfoRow(label: 'Total dibayar', value: formatRupiah(iuran.amount)),
          const SizedBox(height: 12),
          const StatusChip(status: stLunas),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => downloadInvoice(context),
            icon: const Icon(Icons.download_outlined),
            label: const Text('UNDUH / CETAK PDF'),
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
          ),
          const Text('Kuitansi hanya tersedia setelah pembayaran berstatus Sudah Dibayar.', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
