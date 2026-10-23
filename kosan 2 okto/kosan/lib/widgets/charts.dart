// ============================================================
// GRAFIK & KARTU RINGKASAN KEUANGAN
// ============================================================

import 'package:flutter/material.dart';

import '../core/helpers.dart';
import '../data/data.dart';

// ------------------------------------------------------------
// GRAFIK TREN BULANAN
// Grafik batang vertikal untuk membandingkan pemasukan dan pengeluaran per bulan.
// ------------------------------------------------------------

class MonthlyTrendChart extends StatelessWidget {
  final List<DateTime> months; // daftar bulan yang ditampilkan (urut lama -> baru)
  final String Function(DateTime) monthLabel; // fungsi pembuat nama bulan

  const MonthlyTrendChart({super.key, required this.months, required this.monthLabel});

  @override
  Widget build(BuildContext context) {
    // Hitung total pemasukan & pengeluaran tiap bulan
    final data = months.map((month) {
      final items = transactions.where((t) => transactionInMonth(t, month));
      return <String, Object>{
        'month': month,
        'income': items.where((t) => t.type == 'Pemasukan').fold<double>(0.0, (sum, t) => sum + t.amount),
        'expense': items.where((t) => t.type == 'Pengeluaran').fold<double>(0.0, (sum, t) => sum + t.amount),
      };
    }).toList();
    // Nilai terbesar dipakai untuk skala tinggi batang
    double maxAmount = 0;
    for (final row in data) {
      final income = row['income'] as double;
      final expense = row['expense'] as double;
      if (income > maxAmount) maxAmount = income;
      if (expense > maxAmount) maxAmount = expense;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Legenda warna
          Row(children: [
            Container(width: 11, height: 11, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
            const SizedBox(width: 5), const Text('Pemasukan', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 14),
            Container(width: 11, height: 11, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
            const SizedBox(width: 5), const Text('Pengeluaran', style: TextStyle(fontSize: 12)),
          ]),
          const SizedBox(height: 18),
          // Batang tiap bulan
          SizedBox(
            height: 220,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: data.map((row) {
                final month = row['month'] as DateTime;
                final income = row['income'] as double;
                final expense = row['expense'] as double;
                final availableHeight = 154.0; // tinggi maksimum batang
                // Tinggi batang = persentase terhadap nilai terbesar
                final incomeHeight = maxAmount == 0 ? 0.0 : (income / maxAmount * availableHeight).clamp(0.0, availableHeight).toDouble();
                final expenseHeight = maxAmount == 0 ? 0.0 : (expense / maxAmount * availableHeight).clamp(0.0, availableHeight).toDouble();
                final label = monthLabel(month).split(' ').first.substring(0, 3); // 3 huruf pertama nama bulan
                return Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    SizedBox(height: 18, child: FittedBox(fit: BoxFit.scaleDown, child: Text(income >= 1000000 ? '${(income / 1000000).toStringAsFixed(1)} jt' : '${(income / 1000).round()} rb', style: const TextStyle(fontSize: 9, color: Colors.green)))),
                    const SizedBox(height: 3),
                    SizedBox(height: availableHeight, child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Tooltip(message: 'Pemasukan $label: ${formatRupiah(income)}', child: Container(width: 12, height: incomeHeight, decoration: const BoxDecoration(color: Colors.green, borderRadius: BorderRadius.vertical(top: Radius.circular(4))))),
                      const SizedBox(width: 3),
                      Tooltip(message: 'Pengeluaran $label: ${formatRupiah(expense)}', child: Container(width: 12, height: expenseHeight, decoration: const BoxDecoration(color: Colors.red, borderRadius: BorderRadius.vertical(top: Radius.circular(4))))),
                    ])),
                    const SizedBox(height: 7),
                    Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ));
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Arahkan kursor ke batang untuk melihat nominal lengkap.', style: TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------
// KARTU PENGELUARAN PER KATEGORI
// Menjawab pertanyaan admin: "pengeluaran bulan ini berapa, dan untuk apa saja?"
// Dipakai di Dashboard Admin dan Laporan Keuangan.
// ------------------------------------------------------------

class ExpenseBreakdownCard extends StatelessWidget {
  final DateTime month; // bulan yang dirinci

  const ExpenseBreakdownCard({super.key, required this.month});

  @override
  Widget build(BuildContext context) {
    final items = expenseBreakdown(month); // sudah terurut dari terbesar
    final total = items.fold<double>(0.0, (sum, e) => sum + e.value);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pengeluaran per Kategori • ${monthLabel(month)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Total ${formatRupiah(total)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (items.isEmpty)
              const Text('Belum ada pengeluaran pada bulan ini.', style: TextStyle(color: Colors.grey))
            else
              ...items.map((e) {
                final percent = total == 0 ? 0.0 : e.value / total; // porsi terhadap total
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(expenseIcon(e.key), size: 20, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                          Text('${formatRupiah(e.value)} (${(percent * 100).round()}%)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: percent,
                          minHeight: 8,
                          color: Colors.red,
                          backgroundColor: Colors.red.withValues(alpha: 0.10),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
