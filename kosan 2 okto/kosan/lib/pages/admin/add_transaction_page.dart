// ============================================================
// TAMBAH / EDIT TRANSAKSI (kategori berupa pilihan)
// - transaction != null -> mode EDIT
// - type / category     -> nilai awal saat tambah baru
// ============================================================

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class AddTransactionPage extends StatefulWidget {
  final TransactionData? transaction;
  final String? type;
  final String? category;

  const AddTransactionPage({super.key, this.transaction, this.type, this.category});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  late TextEditingController dateController;
  late TextEditingController descriptionController;
  late TextEditingController amountController;
  late String selectedType;
  late String selectedCategory;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    // Jika edit, isi form dengan data lama; jika baru, pakai nilai default
    dateController = TextEditingController(text: t?.date ?? formatDate(today));
    descriptionController = TextEditingController(text: t?.description ?? widget.category ?? '');
    amountController = TextEditingController(text: t != null ? t.amount.toStringAsFixed(0) : '');
    selectedType = t?.type ?? widget.type ?? 'Pemasukan';
    selectedCategory = t?.category ?? widget.category ?? categoriesFor(selectedType).first;
  }

  // Memilih tanggal transaksi
  Future<void> pickTransactionDate() async {
    final current = parseDate(dateController.text) ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => dateController.text = formatDate(picked));
  }

  // Validasi lalu simpan transaksi (baru / hasil edit)
  void saveTransaction() {
    final amount = double.tryParse(amountController.text) ?? 0;

    if (descriptionController.text.trim().isEmpty || amount <= 0) {
      showMessage(context, 'Lengkapi data transaksi terlebih dahulu.');
      return;
    }

    if (widget.transaction != null) {
      // Mode edit: ubah data transaksi yang sudah ada
      widget.transaction!.date = dateController.text.trim();
      widget.transaction!.description = descriptionController.text.trim();
      widget.transaction!.category = selectedCategory;
      widget.transaction!.type = selectedType;
      widget.transaction!.amount = amount;
    } else {
      // Mode tambah: buat transaksi baru
      transactions.add(TransactionData(
        id: DateTime.now().millisecondsSinceEpoch,
        date: dateController.text.trim(),
        description: descriptionController.text.trim(),
        category: selectedCategory,
        type: selectedType,
        amount: amount,
      ));
    }

    notifyDataChanged();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.transaction != null;
    final cats = categoriesFor(selectedType, selectedCategory);

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Transaksi' : 'Tambah Transaksi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tanggal
          InkWell(
            onTap: pickTransactionDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Tanggal', prefixIcon: Icon(Icons.calendar_today_outlined)),
              child: Text(dateController.text),
            ),
          ),
          const SizedBox(height: 14),
          // Jenis transaksi
          DropdownButtonFormField<String>(
            initialValue: selectedType,
            decoration: const InputDecoration(
              labelText: 'Jenis Transaksi',
              prefixIcon: Icon(Icons.swap_vert_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'Pemasukan', child: Text('Pemasukan')),
              DropdownMenuItem(value: 'Pengeluaran', child: Text('Pengeluaran')),
            ],
            onChanged: (value) => setState(() {
              selectedType = value!;
              // Jika kategori lama tidak cocok dengan jenis baru, ganti ke kategori pertama
              if (!categoriesFor(selectedType).contains(selectedCategory)) {
                selectedCategory = categoriesFor(selectedType).first;
              }
            }),
          ),
          const SizedBox(height: 14),
          field(descriptionController, 'Deskripsi (contoh: Listrik bulan Oktober)', Icons.description_outlined),
          // Kategori berupa pilihan (daftar berubah sesuai jenis transaksi)
          DropdownButtonFormField<String>(
            key: ValueKey('$selectedType-$selectedCategory'),
            initialValue: selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Kategori',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: cats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (value) => setState(() => selectedCategory = value!),
          ),
          const SizedBox(height: 14),
          // Nominal
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Nominal',
              prefixText: 'Rp ',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: saveTransaction,
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
              child: Text(isEdit ? 'SIMPAN PERUBAHAN' : 'SIMPAN'),
            ),
          ),
        ],
      ),
    );
  }
}
