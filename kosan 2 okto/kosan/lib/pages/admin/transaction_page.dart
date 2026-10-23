// ============================================================
// DAFTAR TRANSAKSI (admin)
// - Pemasukan iuran tercatat otomatis dari menu Iuran.
// - Bagian "Pengeluaran Rutin" = checklist biaya bulanan pemilik (listrik, air, wifi, penjaga).
// - Tombol + dipakai untuk mencatat pengeluaran lain (lampu, perbaikan, dll).
// ============================================================

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';
import '../pages.dart';

class TransactionPage extends StatefulWidget {
  const TransactionPage({super.key});

  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  String filter = 'Semua';

  // Membuka form tambah transaksi (bisa dengan kategori yang sudah terpilih) lalu segarkan halaman
  Future<void> _openForm({String type = 'Pengeluaran', String? category}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddTransactionPage(type: type, category: category)),
    );
    if (mounted) setState(() {});
  }

  // Checklist pengeluaran rutin bulan ini: centang hijau jika sudah dicatat, tombol "Catat" jika belum
  Widget _routineCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pengeluaran Rutin • ${monthLabel(today)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            const Text('Biaya bulanan yang dibayar pemilik kos. Catat agar tidak terlewat.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 6),
            ...routineExpenseCategories.map((cat) {
              // Sudah dicatat jika ada transaksi pengeluaran kategori ini di bulan berjalan
              final done = transactions.any((t) => t.type == 'Pengeluaran' && t.category == cat && transactionInMonth(t, today));
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? Colors.green : Colors.grey),
                title: Text(cat),
                trailing: done
                    ? const Pill(text: 'Sudah dicatat', color: Colors.green)
                    : TextButton(onPressed: () => _openForm(category: cat), child: const Text('Catat')),
              );
            }),
          ],
        ),
      ),
    );
  }

  // Kartu satu transaksi lengkap dengan tombol edit & hapus
  Widget _transactionCard(TransactionData transaction) {
    final isIncome = transaction.type == 'Pemasukan';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isIncome ? lightGreen : Colors.red.shade50,
            child: Icon(
              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIncome ? Colors.green : Colors.red,
            ),
          ),
          title: Text(transaction.description, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text('${transaction.date}\n${transaction.category} • ${transaction.type}'),
          ),
          isThreeLine: true,
          trailing: SizedBox(
            width: 90,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatRupiah(transaction.amount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isIncome ? Colors.green : Colors.red,
                    fontSize: 12,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Tombol edit
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.edit_outlined, size: 19),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddTransactionPage(transaction: transaction),
                          ),
                        );
                        if (mounted) setState(() {});
                      },
                    ),
                    const SizedBox(width: 8),
                    // Tombol hapus
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.delete_outline, size: 19, color: Colors.red),
                      onPressed: () async {
                        final ok = await confirmAction(context, 'Hapus transaksi?', 'Transaksi ini akan dihapus dan tidak dapat dikembalikan.');
                        if (!ok) return;
                        setState(() {
                          transactions.removeWhere((item) => item.id == transaction.id);
                          notifyDataChanged();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter + urut dari yang terbaru
    final List<TransactionData> data = (filter == 'Semua'
        ? List<TransactionData>.from(transactions)
        : transactions.where((item) => item.type == filter).toList())
      ..sort((a, b) => b.id.compareTo(a.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Transaksi')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Filter jenis transaksi
          DropdownButtonFormField<String>(
            initialValue: filter,
            decoration: const InputDecoration(labelText: 'Filter Transaksi'),
            items: const [
              DropdownMenuItem(value: 'Semua', child: Text('Semua Transaksi')),
              DropdownMenuItem(value: 'Pemasukan', child: Text('Pemasukan')),
              DropdownMenuItem(value: 'Pengeluaran', child: Text('Pengeluaran')),
            ],
            onChanged: (value) => setState(() => filter = value!),
          ),
          const SizedBox(height: 8),
          // Checklist pengeluaran rutin bulan ini
          _routineCard(),
          // Info cara kerja pencatatan
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'Pembayaran penghuni (termasuk tunai) tercatat otomatis lewat menu Iuran & Reminder. '
              'Gunakan tombol + untuk pengeluaran lain (lampu, perbaikan, dll) atau pemasukan ganti rugi dari penghuni.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          // Daftar transaksi
          if (data.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 30),
              child: EmptyState(icon: Icons.receipt_long, message: 'Belum ada transaksi.'),
            )
          else
            ...data.map(_transactionCard),
        ],
      ),
      // Tombol + : catat transaksi baru (default pengeluaran)
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
