// ============================================================
// BOOKING (listrik & air sudah masuk di total)
// ============================================================

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';
import '../../services/api_service.dart';
import '../../services/db_sync.dart';

class BookingPage extends StatefulWidget {
  final Room room; // kamar yang dipesan
  final UserAccount user; // penghuni yang memesan

  const BookingPage({super.key, required this.room, required this.user});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  DateTime start = today; // tanggal masuk
  int months = 1; // durasi sewa (bulan)
  final voucherC = TextEditingController();
  String appliedVoucher = ''; // kode voucher yang sah
  Map<String, dynamic>? _serverQuote;
  bool _quoteLoading = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _refreshQuote();
  }

  // Perhitungan diskon & total
  double get durationDiscount => months >= 12 ? 0.15 : (months >= 6 ? 0.08 : 0.0); // diskon durasi
  double get voucherDiscount => appliedVoucher == 'KOSHEMAT5' ? 0.05 : (appliedVoucher == 'AJAKTEMAN10' ? 0.10 : 0.0);
  double get rentSubtotal => roomTypes[widget.room.typeIndex].finalPrice * months; // sewa sebelum diskon tambahan
  double _quoteNumber(String key, double fallback) {
    final value = _serverQuote?[key];
    return value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double get rentTotal => _quoteNumber('rent_total', rentSubtotal * (1 - durationDiscount) * (1 - voucherDiscount));
  double get utilityTotal => _quoteNumber('utility_fee_total', utilityFee * months);
  double get grandTotal => _quoteNumber('total', rentTotal + utilityTotal); // harga dari server menjadi sumber utama

  // Harga dan voucher divalidasi oleh backend; tampilan lokal hanya fallback sementara.
  Future<void> _refreshQuote() async {
    final roomTypeId = widget.room.roomTypeId ?? roomTypes[widget.room.typeIndex].id;
    if (roomTypeId == null) return;
    setState(() => _quoteLoading = true);
    try {
      final response = await ApiService.post('pricing/quote', {
        'room_type_id': roomTypeId,
        'months': months,
        if (appliedVoucher.isNotEmpty) 'voucher_code': appliedVoucher,
      });
      final data = response['data'];
      if (data is Map && mounted) setState(() => _serverQuote = Map<String, dynamic>.from(data));
    } on ApiException catch (error) {
      if (appliedVoucher.isNotEmpty && mounted) {
        setState(() {
          appliedVoucher = '';
          _serverQuote = null;
        });
        showMessage(context, error.message);
      }
    } finally {
      if (mounted) setState(() => _quoteLoading = false);
    }
  }

  Future<void> applyVoucher() async {
    final code = voucherC.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => appliedVoucher = '');
      await _refreshQuote();
      return;
    }
    setState(() => appliedVoucher = code);
    await _refreshQuote();
    if (mounted && appliedVoucher == code && _serverQuote != null) {
      showMessage(context, 'Voucher $code berhasil divalidasi server.');
    }
  }

  // Memilih tanggal masuk
  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => start = picked);
  }

  // Booking dibuat oleh server; harga final tidak pernah diterima dari Flutter.
  Future<void> confirm() async {
    final room = widget.room;
    if (room.id == null) {
      showMessage(context, 'ID kamar dari server tidak tersedia. Muat ulang daftar kamar.');
      return;
    }
    if (roomOf(widget.user) != null) {
      showMessage(context, 'Anda sudah memiliki kamar atau booking aktif.');
      return;
    }
    if (room.status != 'Kosong') {
      showMessage(context, 'Maaf, kamar ini sudah tidak tersedia.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ApiService.post('bookings', {
        'room_id': room.id,
        'months': months,
        'check_in': '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
        if (appliedVoucher.isNotEmpty) 'voucher_code': appliedVoucher,
      });
      await DbSync.loadAll();
      if (!mounted) return;
      showMessage(context, 'Booking berhasil. Selesaikan pembayaran dalam 24 jam. Kamar aktif setelah pembayaran dikonfirmasi.');
      Navigator.pop(context);
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final type = roomTypes[room.typeIndex];

    return Scaffold(
      appBar: AppBar(title: Text('Booking Kamar ${room.number}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RoomCard(room: room),
          const SizedBox(height: 8),
          // Pilih tanggal masuk
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today_outlined, color: primaryGreen),
              title: const Text('Tanggal Masuk'),
              subtitle: Text(formatDate(start)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: pickDate,
            ),
          ),
          const SizedBox(height: 8),
          // Pilih durasi sewa
          DropdownButtonFormField<int>(
            initialValue: months,
            decoration: const InputDecoration(labelText: 'Durasi Sewa', prefixIcon: Icon(Icons.timelapse_outlined)),
            items: const [1, 3, 6, 12].map((m) => DropdownMenuItem(value: m, child: Text('$m bulan'))).toList(),
            onChanged: (v) { if (v != null) { setState(() => months = v); _refreshQuote(); } },
          ),
          const SizedBox(height: 12),
          // Input voucher
          TextField(
            controller: voucherC,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Kode Voucher (opsional)',
              hintText: 'KOSHEMAT5 / AJAKTEMAN10',
              prefixIcon: const Icon(Icons.confirmation_number_outlined),
              suffixIcon: TextButton(onPressed: applyVoucher, child: const Text('Pakai')),
            ),
          ),
          const SizedBox(height: 8),
          // Rincian biaya
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  InfoRow(label: 'Sewa / bulan', value: formatRupiah(type.finalPrice)),
                  InfoRow(label: 'Durasi sewa', value: '$months bulan'),
                  InfoRow(label: 'Selesai sewa', value: formatDate(addMonths(start, months))),
                  InfoRow(label: 'Subtotal sewa', value: formatRupiah(rentSubtotal)),
                  InfoRow(label: 'Diskon durasi', value: '${_quoteNumber('duration_discount_percent', durationDiscount * 100).round()}%'),
                  InfoRow(label: 'Diskon voucher', value: '${_quoteNumber('voucher_discount_percent', voucherDiscount * 100).round()}%'),
                  if (appliedVoucher.isNotEmpty) InfoRow(label: 'Voucher', value: appliedVoucher),
                  InfoRow(label: 'Sewa setelah diskon', value: formatRupiah(rentTotal)),
                  InfoRow(label: 'Listrik & air ($months bln)', value: formatRupiah(utilityTotal)),
                  const Divider(),
                  InfoRow(label: 'TOTAL BAYAR (LUNAS)', value: _quoteLoading ? 'Menghitung...' : formatRupiah(grandTotal)),
                  const SizedBox(height: 6),
                  const Text(
                    'Listrik & air sudah termasuk dalam tagihan (tarif tetap), jadi tidak perlu input meter. '
                    'Pembayaran harus lunas 100% (tidak bisa dicicil) dalam 24 jam. '
                    'Kamar baru aktif setelah pembayaran dikonfirmasi pemilik kos.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: (_submitting || _quoteLoading) ? null : confirm,
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
              child: Text(_submitting ? 'Memproses...' : 'KONFIRMASI BOOKING'),
            ),
          ),
        ],
      ),
    );
  }
}
