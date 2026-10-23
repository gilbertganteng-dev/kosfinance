// ============================================================
// BOOKING (listrik & air sudah masuk di total)
// ============================================================

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

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

  // Perhitungan diskon & total
  double get durationDiscount => months >= 12 ? 0.15 : (months >= 6 ? 0.08 : 0.0); // diskon durasi
  double get voucherDiscount => appliedVoucher == 'KOSHEMAT5' ? 0.05 : (appliedVoucher == 'AJAKTEMAN10' ? 0.10 : 0.0);
  double get rentSubtotal => roomTypes[widget.room.typeIndex].finalPrice * months; // sewa sebelum diskon tambahan
  double get rentTotal => rentSubtotal * (1 - durationDiscount) * (1 - voucherDiscount); // sewa setelah diskon
  double get utilityTotal => utilityFee * months; // listrik & air (tidak kena diskon)
  double get grandTotal => rentTotal + utilityTotal; // total yang harus dibayar lunas

  // Memeriksa kode voucher
  void applyVoucher() {
    final code = voucherC.text.trim().toUpperCase();
    if (code == 'KOSHEMAT5' || code == 'AJAKTEMAN10') {
      setState(() => appliedVoucher = code);
      showMessage(context, 'Voucher $code berhasil digunakan.');
    } else {
      setState(() => appliedVoucher = '');
      showMessage(context, 'Kode voucher tidak valid.');
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

  // Konfirmasi booking: kamar jadi "Dipesan" dan tagihan dibuat
  void confirm() {
    final room = widget.room;

    // Satu penghuni hanya boleh punya satu kamar
    if (roomOf(widget.user) != null) {
      showMessage(context, 'Anda sudah memiliki kamar atau booking aktif.');
      return;
    }
    // Pastikan kamar belum diambil orang lain
    if (room.status != 'Kosong') {
      showMessage(context, 'Maaf, kamar ini sudah tidak tersedia.');
      return;
    }

    // Status "Dipesan" = BELUM aktif. Baru jadi "Terisi" setelah lunas dikonfirmasi (lihat markPaid).
    room.status = 'Dipesan';
    room.residentName = widget.user.name;
    room.checkIn = start;
    room.checkOut = addMonths(start, months);
    iuranList.add(IuranData(
      id: DateTime.now().millisecondsSinceEpoch,
      residentName: widget.user.name,
      roomNumber: room.number,
      iuranType: 'Sewa $months Bulan',
      amount: grandTotal,
      dueDate: formatDate(today.add(const Duration(days: 1))),
      status: stBelum,
      isBooking: true,
      bookingDeadline: DateTime.now().add(const Duration(hours: 24)), // batas bayar 24 jam
    ));
    addAdminNotification(
      type: 'booking',
      title: 'Booking kamar baru',
      message: '${widget.user.name} mengajukan booking kamar ${room.number}.',
    );

    notifyDataChanged();
    showMessage(context, 'Booking berhasil. Bayar LUNAS 100% dalam 24 jam di dashboard. Kamar aktif setelah pembayaran dikonfirmasi.');
    Navigator.pop(context);
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
            onChanged: (v) => setState(() => months = v!),
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
                  InfoRow(label: 'Diskon durasi', value: '${(durationDiscount * 100).round()}%'),
                  InfoRow(label: 'Diskon voucher', value: '${(voucherDiscount * 100).round()}%'),
                  if (appliedVoucher.isNotEmpty) InfoRow(label: 'Voucher', value: appliedVoucher),
                  InfoRow(label: 'Sewa setelah diskon', value: formatRupiah(rentTotal)),
                  InfoRow(label: 'Listrik & air ($months bln)', value: formatRupiah(utilityTotal)),
                  const Divider(),
                  InfoRow(label: 'TOTAL BAYAR (LUNAS)', value: formatRupiah(grandTotal)),
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
              onPressed: confirm,
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
              child: const Text('KONFIRMASI BOOKING'),
            ),
          ),
        ],
      ),
    );
  }
}
