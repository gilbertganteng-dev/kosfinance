// ============================================================
// IURAN & RIWAYAT (penghuni) - tagihan + riwayat pembayaran jadi satu
// ============================================================

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';
import '../pages.dart';

class MyIuranPage extends StatefulWidget {
  final UserAccount user;

  const MyIuranPage({super.key, required this.user});

  @override
  State<MyIuranPage> createState() => _MyIuranPageState();
}

class _MyIuranPageState extends State<MyIuranPage> {
  // Kartu satu tagihan yang belum lunas
  Widget _billCard(IuranData iuran) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Kamar ${iuran.roomNumber}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                StatusChip(status: iuran.status),
              ],
            ),
            const Divider(height: 28),
            InfoRow(label: 'Jenis Iuran', value: iuran.iuranType),
            InfoRow(label: 'Nominal', value: formatRupiah(iuran.amount)),
            InfoRow(label: 'Jatuh Tempo', value: iuran.dueDate),
            if (iuran.bookingDeadline != null && iuran.status == stBelum)
              InfoRow(label: 'Bayar sebelum', value: formatDateTime(iuran.bookingDeadline!)),
            if (iuran.paymentMethod != null) InfoRow(label: 'Metode Bayar', value: iuran.paymentMethod!),
            const SizedBox(height: 12),
            // Indikator 3 tahap pembayaran
            PaymentSteps(status: iuran.status),
            if (iuran.status == stBelum) ...[
              const SizedBox(height: 14),
              if (iuran.rejectNote != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text('Pembayaran sebelumnya ditolak: ${iuran.rejectNote}', style: const TextStyle(color: Colors.red)),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (context) => PaymentPage(iuran: iuran)));
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.payment),
                  label: const Text('Bayar Sekarang (Lunas)'),
                  style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    expireBookingReservations(notify: false);
    // Semua tagihan penghuni, diurutkan dari yang terbaru
    final all = iuranFor(widget.user)..sort((a, b) => b.id.compareTo(a.id));
    final pending = all.where((i) => i.status != stLunas).toList(); // belum lunas
    final paid = all.where((i) => i.status == stLunas).toList(); // riwayat lunas

    return Scaffold(
      appBar: AppBar(title: const Text('Iuran & Riwayat')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Tagihan yang harus dibayar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (pending.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Tidak ada tagihan. Semua sudah lunas.', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...pending.map(_billCard),
          const SizedBox(height: 18),
          const Text('Riwayat pembayaran', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (paid.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Belum ada pembayaran yang lunas.', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...paid.map((i) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.withValues(alpha: 0.12),
                      child: const Icon(Icons.check, color: Colors.green),
                    ),
                    title: Text('${i.iuranType} • Kamar ${i.roomNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Dibayar ${i.paidAt == null ? '-' : formatDate(i.paidAt!)}${i.paymentMethod != null ? ' • ${i.paymentMethod}' : ''}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(formatRupiah(i.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        // Link ke kuitansi PDF
                        InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => InvoicePage(user: widget.user, iuran: i)),
                          ),
                          child: const Text('Invoice', style: TextStyle(fontSize: 12, color: primaryGreen, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}
