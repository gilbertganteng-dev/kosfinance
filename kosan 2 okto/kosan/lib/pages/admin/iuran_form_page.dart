// ============================================================
// FORM TAMBAH / EDIT IURAN
// ============================================================

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class IuranFormPage extends StatefulWidget {
  final IuranData? iuran; // null = tambah baru, ada isi = edit

  const IuranFormPage({super.key, this.iuran});

  @override
  State<IuranFormPage> createState() => _IuranFormPageState();
}

class _IuranFormPageState extends State<IuranFormPage> {
  late TextEditingController nameController;
  late TextEditingController roomController;
  late TextEditingController typeController;
  late TextEditingController amountController;
  late TextEditingController dueDateController;
  String status = stBelum;

  @override
  void initState() {
    super.initState();
    final iuran = widget.iuran;
    nameController = TextEditingController(text: iuran?.residentName ?? '');
    roomController = TextEditingController(text: iuran?.roomNumber ?? '');
    typeController = TextEditingController(text: iuran?.iuranType ?? 'Iuran Bulanan');
    amountController = TextEditingController(text: iuran != null ? iuran.amount.toStringAsFixed(0) : '');
    dueDateController = TextEditingController(text: iuran?.dueDate ?? formatDate(today));
    status = iuran?.status ?? stBelum;
  }

  // Validasi lalu simpan iuran
  void saveIuran() {
    final amount = double.tryParse(amountController.text) ?? 0;

    if (nameController.text.trim().isEmpty || roomController.text.trim().isEmpty || amount <= 0) {
      showMessage(context, 'Lengkapi data iuran terlebih dahulu.');
      return;
    }

    final old = widget.iuran?.status; // status sebelum diedit
    // Jika tambah baru, buat objek kosong dulu lalu diisi di bawah
    final item = widget.iuran ??
        IuranData(
          id: DateTime.now().millisecondsSinceEpoch,
          residentName: '',
          roomNumber: '',
          iuranType: '',
          amount: 0,
          dueDate: '',
          status: stBelum,
        );

    item.residentName = nameController.text.trim();
    item.roomNumber = roomController.text.trim();
    item.iuranType = typeController.text.trim();
    item.amount = amount;
    item.dueDate = dueDateController.text.trim();
    if (widget.iuran == null) iuranList.add(item);

    if (status == stLunas) {
      item.status = old ?? stBelum;
      markPaid(item); // sekaligus mengaktifkan kamar kalau ini tagihan booking
    } else if (old == stLunas) {
      markUnpaid(item); // dibatalkan: pemasukan terkait ikut dihapus
      item.status = status;
    } else {
      item.status = status;
    }
    notifyDataChanged();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.iuran == null ? 'Tambah Iuran' : 'Edit Iuran')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          field(nameController, 'Nama Penghuni', Icons.person_outline),
          field(roomController, 'Nomor Kamar', Icons.home_outlined),
          field(typeController, 'Jenis Iuran', Icons.category_outlined),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Nominal',
              prefixText: 'Rp ',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 14),
          field(dueDateController, 'Tanggal Jatuh Tempo (dd/MM/yyyy)', Icons.calendar_today_outlined),
          DropdownButtonFormField<String>(
            initialValue: status,
            decoration: const InputDecoration(
              labelText: 'Status Pembayaran',
              prefixIcon: Icon(Icons.check_circle_outline),
            ),
            items: const [stBelum, stProses, stLunas]
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (value) => setState(() => status = value!),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: saveIuran,
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
              child: const Text('SIMPAN'),
            ),
          ),
        ],
      ),
    );
  }
}
