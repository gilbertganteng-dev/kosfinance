// ============================================================
// WIDGET REUSABLE (dipakai berulang di banyak halaman)
// ============================================================

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/helpers.dart';
import '../data/data.dart';
import '../models/models.dart';

// Kolom input teks dengan ikon (dipakai di banyak form)
Widget field(
  TextEditingController c,
  String label,
  IconData icon, {
  bool obscure = false,
  TextInputType? type,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: type,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    ),
  );
}

// Kartu ringkasan angka (ikon + judul + nilai)
class SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Judul bagian + tombol aksi opsional di kanan
class SectionTitle extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onAction;

  const SectionTitle({super.key, required this.title, this.actionText, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        if (actionText != null) TextButton(onPressed: onAction, child: Text(actionText!)),
      ],
    );
  }
}

// Bar horizontal perbandingan nominal
class FinancialBar extends StatelessWidget {
  final String title;
  final double amount;
  final double maxAmount;
  final Color color;

  const FinancialBar({
    super.key,
    required this.title,
    required this.amount,
    required this.maxAmount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Panjang bar = nominal dibanding nilai terbesar (0.0 - 1.0)
    final percentage = maxAmount == 0 ? 0.0 : amount / maxAmount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(formatRupiah(amount), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 13,
              color: color,
              backgroundColor: color.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }
}

// Kartu satu transaksi (dipakai di dashboard admin)
class TransactionCard extends StatelessWidget {
  final TransactionData transaction;

  const TransactionCard({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'Pemasukan';

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isIncome ? lightGreen : Colors.red.shade50,
          child: Icon(
            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            color: isIncome ? Colors.green : Colors.red,
          ),
        ),
        title: Text(transaction.description, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${transaction.date} • ${transaction.category}'),
            // Tombol lihat bukti jika ada
            if (transaction.proofBytes != null)
              TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => Dialog(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: InteractiveViewer(
                        child: Image.memory(transaction.proofBytes!, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ),
                icon: const Icon(Icons.image_outlined, size: 16),
                label: const Text('Lihat bukti pembayaran'),
              ),
          ],
        ),
        trailing: Text(
          formatRupiah(transaction.amount),
          style: TextStyle(
            color: isIncome ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// Label kecil berwarna (pill)
class Pill extends StatelessWidget {
  final String text;
  final Color color;

  const Pill({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

// Label status pembayaran
class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) => Pill(text: status, color: statusColor(status));
}

// Indikator 3 tahap pembayaran (Belum -> Menunggu -> Lunas)
class PaymentSteps extends StatelessWidget {
  final String status;

  const PaymentSteps({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    const labels = [stBelum, stProses, stLunas];
    final idx = labels.indexOf(status); // tahap saat ini
    final activeColor = statusColor(status);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(3, (i) {
        final done = i <= idx; // tahap yang sudah tercapai diberi warna
        final c = done ? activeColor : Colors.grey.shade400;
        return Expanded(
          child: Column(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: c,
                child: Icon(done ? Icons.check : Icons.circle_outlined, size: 15, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: c, fontWeight: i == idx ? FontWeight.bold : FontWeight.normal),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// Kartu informasi satu kamar
class RoomCard extends StatelessWidget {
  final Room room;
  final bool showResident; // true = tampilkan info penghuni (tampilan admin)
  final List<Widget> actions; // tombol aksi tambahan

  const RoomCard({
    super.key,
    required this.room,
    this.showResident = false,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final type = roomTypes[room.typeIndex];
    // Sisa hari hanya relevan kalau kamar benar-benar aktif (Terisi)
    final days = room.status == 'Terisi' ? room.daysLeft : null;
    final urgent = days != null && days <= 7; // merah jika sisa <= 7 hari

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Kamar ${room.number}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Pill(text: room.status, color: roomColor(room.status)),
              ],
            ),
            const SizedBox(height: 4),
            Text(type.name, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                Pill(text: type.ac ? 'Ber-AC' : 'Tanpa AC', color: Colors.blue),
                Pill(text: type.wcDalam ? 'WC Dalam' : 'WC Luar', color: Colors.teal),
                if (type.discount > 0) Pill(text: 'Diskon ${type.discount}%', color: Colors.red),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${formatRupiah(type.finalPrice)} / bulan',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryGreen),
            ),
            // Info penghuni (khusus tampilan admin)
            if (showResident && room.residentName != null) ...[
              const Divider(height: 24),
              InfoRow(label: 'Penghuni', value: room.residentName!),
              if (room.checkIn != null) InfoRow(label: 'Mulai', value: formatDate(room.checkIn!)),
              if (room.checkOut != null) InfoRow(label: 'Berakhir', value: formatDate(room.checkOut!)),
              if (days != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Pill(
                    text: days < 0 ? 'Kontrak berakhir ${-days} hari lalu' : 'Sisa $days hari',
                    color: urgent ? Colors.red : Colors.green,
                  ),
                ),
            ],
            // Tombol aksi admin
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 6, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

// Kotak statistik kecil (angka + label)
class MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const MiniStat({super.key, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

// Baris label (kiri) + nilai (kanan). valueColor opsional, mis. merah untuk terlambat.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const InfoRow({super.key, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.grey))),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w600, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

// Kartu satu data profil
class ProfileInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const ProfileInfoCard({super.key, required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: lightGreen,
          child: Icon(icon, color: primaryGreen),
        ),
        title: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }
}

// Tampilan saat data kosong
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, // aman dipakai di dalam ListView
        children: [
          Icon(icon, size: 60, color: Colors.grey),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
