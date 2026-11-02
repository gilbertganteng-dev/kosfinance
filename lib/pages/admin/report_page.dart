// ============================================================
// LAPORAN KEUANGAN
// ============================================================

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  late DateTime selectedMonth; // bulan laporan yang dipilih

  @override
  void initState() {
    super.initState();
    selectedMonth = DateTime(today.year, today.month);
    appDataRevision.addListener(_refreshData);
  }

  void _refreshData() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appDataRevision.removeListener(_refreshData);
    super.dispose();
  }

  // Transaksi pada bulan yang dipilih
  List<TransactionData> get monthTransactions =>
      transactions.where((t) => transactionInMonth(t, selectedMonth)).toList();

  double get totalIncome => monthTransactions
      .where((t) => t.type == 'Pemasukan')
      .fold<double>(0.0, (sum, t) => sum + t.amount);

  double get totalExpense => monthTransactions
      .where((t) => t.type == 'Pengeluaran')
      .fold<double>(0.0, (sum, t) => sum + t.amount);

  @override
  Widget build(BuildContext context) {
    final balance = totalIncome - totalExpense;
    final maxAmount = totalIncome > totalExpense ? totalIncome : totalExpense;
    // 6 bulan terakhir (termasuk bulan ini)
    final months = List.generate(6, (index) => DateTime(today.year, today.month - index));

    return Scaffold(
      appBar: AppBar(title: const Text('Laporan Keuangan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Ringkasan Keuangan', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Laporan dihitung dari transaksi yang tercatat, bukan dari tagihan yang belum dibayar.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 14),
          // Pilih periode laporan
          DropdownButtonFormField<DateTime>(
            initialValue: selectedMonth,
            decoration: const InputDecoration(labelText: 'Periode laporan', prefixIcon: Icon(Icons.calendar_month_outlined)),
            items: months.map((m) => DropdownMenuItem(value: m, child: Text(monthLabel(m)))).toList(),
            onChanged: (value) { if (value != null) setState(() => selectedMonth = value); },
          ),
          const SizedBox(height: 16),
          SummaryCard(title: 'Pemasukan', value: formatRupiah(totalIncome), icon: Icons.trending_up, color: Colors.green),
          SummaryCard(title: 'Pengeluaran', value: formatRupiah(totalExpense), icon: Icons.trending_down, color: Colors.red),
          SummaryCard(title: 'Saldo Bersih', value: formatRupiah(balance), icon: Icons.account_balance_wallet, color: Colors.blue),
          const SizedBox(height: 18),
          Text('Pemasukan vs Pengeluaran • ${monthLabel(selectedMonth)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          FinancialBar(title: 'Pemasukan', amount: totalIncome, maxAmount: maxAmount, color: Colors.green),
          FinancialBar(title: 'Pengeluaran', amount: totalExpense, maxAmount: maxAmount, color: Colors.red),
          const SizedBox(height: 22),
          // Tren 6 bulan
          const Text('Tren 6 Bulan Terakhir', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Batang vertikal membandingkan pemasukan dan pengeluaran setiap bulan.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          MonthlyTrendChart(months: months.reversed.toList(), monthLabel: monthLabel),
          const SizedBox(height: 18),
          // Rincian pengeluaran per kategori pada bulan yang dipilih
          ExpenseBreakdownCard(month: selectedMonth),
          const SizedBox(height: 14),
          // Kondisi keuangan (positif / negatif)
          Card(
            child: ListTile(
              leading: CircleAvatar(backgroundColor: balance >= 0 ? lightGreen : Colors.red.shade50, child: Icon(balance >= 0 ? Icons.check_circle_outline : Icons.warning_amber_outlined, color: balance >= 0 ? Colors.green : Colors.red)),
              title: const Text('Kondisi Keuangan', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(balance >= 0 ? 'Saldo periode ini positif.' : 'Saldo periode ini negatif.'),
            ),
          ),
        ],
      ),
    );
  }
}
