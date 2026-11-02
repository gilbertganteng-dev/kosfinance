// Admin creates a monthly bill through the server. Amount and status are server-controlled.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../../services/api_service.dart';
import '../../services/db_sync.dart';
import '../../widgets/widgets.dart';

class IuranFormPage extends StatefulWidget {
  final dynamic iuran; // Kept for source compatibility; existing bills are not editable.

  const IuranFormPage({super.key, this.iuran});

  @override
  State<IuranFormPage> createState() => _IuranFormPageState();
}

class _IuranFormPageState extends State<IuranFormPage> {
  late final TextEditingController roomController;
  late final TextEditingController dueDateController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    roomController = TextEditingController();
    dueDateController = TextEditingController(text: formatDate(today.add(const Duration(days: 7))));
  }

  Future<void> saveIuran() async {
    if (widget.iuran != null) {
      showMessage(context, 'Tagihan yang sudah dibuat tidak dapat diedit.');
      return;
    }

    final roomNumber = roomController.text.trim();
    final roomMatches = rooms.where((item) => item.number == roomNumber).toList();
    final room = roomMatches.isEmpty ? null : roomMatches.first;
    final dueDate = parseDate(dueDateController.text.trim());
    if (roomNumber.isEmpty || room == null || room.id == null) {
      showMessage(context, 'Masukkan nomor kamar yang valid dari daftar kamar.');
      return;
    }
    if (room.status != 'Terisi') {
      showMessage(context, 'Tagihan bulanan hanya dapat dibuat untuk kamar yang sedang terisi.');
      return;
    }
    if (dueDate == null || dueDate.isBefore(DateTime(today.year, today.month, today.day))) {
      showMessage(context, 'Tanggal jatuh tempo tidak valid. Gunakan format dd/MM/yyyy dan tanggal hari ini atau setelahnya.');
      return;
    }

    final billingMonth = '${today.year}-${today.month.toString().padLeft(2, '0')}';
    final isoDueDate = '${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';
    setState(() => _saving = true);
    try {
      await ApiService.post('bills/monthly', {
        'room_id': room.id,
        'billing_month': billingMonth,
        'due_date': isoDueDate,
      });
      await DbSync.loadAll();
      if (!mounted) return;
      showMessage(context, 'Tagihan bulanan dibuat dengan nominal yang dihitung server.');
      Navigator.pop(context);
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    roomController.dispose();
    dueDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Tagihan Bulanan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Pilih kamar yang sedang terisi. Nominal dihitung otomatis oleh backend berdasarkan harga kamar dan biaya utilitas.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          field(roomController, 'Nomor Kamar', Icons.home_outlined),
          field(dueDateController, 'Tanggal Jatuh Tempo (dd/MM/yyyy)', Icons.calendar_today_outlined),
          const SizedBox(height: 8),
          Text('Periode tagihan: ${today.year}-${today.month.toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : saveIuran,
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
              child: Text(_saving ? 'Menyimpan...' : 'BUAT TAGIHAN'),
            ),
          ),
        ],
      ),
    );
  }
}
