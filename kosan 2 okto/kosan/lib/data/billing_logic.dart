// ============================================================
// LOGIKA TAGIHAN: booking, pembayaran lunas, pembatalan, kadaluarsa
// ============================================================

import '../core/constants.dart';
import '../core/helpers.dart';
import '../models/models.dart';
import 'app_data.dart';

// Mencari kamar yang terkait dengan sebuah tagihan
Room? _roomFor(IuranData i) {
  for (final r in rooms) {
    if (r.number == i.roomNumber && r.residentName == i.residentName) return r;
  }
  return null;
}

// Mencatat pemasukan otomatis dari tagihan yang lunas
void addIncomeFor(IuranData i) {
  transactions.removeWhere((t) => t.sourceIuranId == i.id); // hindari catatan ganda
  transactions.add(TransactionData(
    id: DateTime.now().millisecondsSinceEpoch,
    date: formatDate(today),
    description: 'Pembayaran ${i.iuranType} ${i.residentName}',
    category: 'Iuran',
    type: 'Pemasukan',
    amount: i.amount,
    proofBytes: i.proofBytes,
    sourceIuranId: i.id,
  ));
}

// Menandai tagihan lunas (dipakai admin saat konfirmasi / bayar langsung)
void markPaid(IuranData i) {
  final wasPaid = i.status == stLunas;
  i.status = stLunas;
  i.rejectNote = null;
  i.paidAt ??= DateTime.now();
  addIncomeFor(i); // otomatis jadi pemasukan

  if (!wasPaid) {
    var extra = '';
    final room = _roomFor(i);
    // Kamar baru AKTIF setelah booking lunas 100%
    if (i.isBooking && room != null && room.status == 'Dipesan') {
      room.status = 'Terisi';
      extra = ' Kamar ${room.number} sekarang aktif.';
    }
    // Masa sewa bertambah hanya setelah perpanjangan lunas
    if (i.extendMonths > 0 && room != null && room.status == 'Terisi') {
      room.checkOut = addMonths(room.checkOut ?? today, i.extendMonths);
      extra = ' Masa sewa diperpanjang.';
    }
    addResidentNotification(
      residentName: i.residentName,
      title: 'Pembayaran dikonfirmasi',
      message: 'Pembayaran ${i.iuranType} sebesar ${formatRupiah(i.amount)} sudah lunas.$extra',
    );
  }
  notifyDataChanged();
}

// Membatalkan status lunas (pemasukan terkait ikut dihapus)
void markUnpaid(IuranData i) {
  final wasPaid = i.status == stLunas;
  transactions.removeWhere((t) => t.sourceIuranId == i.id);
  i.status = stBelum;
  i.paidAt = null;
  i.paymentMethod = null;
  i.proofBytes = null;
  i.proofSender = null;

  if (wasPaid) {
    final room = _roomFor(i);
    if (room != null) {
      if (i.isBooking && room.status == 'Terisi') {
        room.status = 'Dipesan';
        i.bookingDeadline = DateTime.now().add(const Duration(hours: 24));
      }
      if (i.extendMonths > 0 && room.checkOut != null) {
        room.checkOut = addMonths(room.checkOut!, -i.extendMonths);
      }
    }
  }
  notifyDataChanged();
}

// Membatalkan booking yang tidak dibayar dalam 24 jam.
// Dipanggil dari build() => notify:false supaya tidak error "setState during build".
void expireBookingReservations({bool notify = true}) {
  final now = DateTime.now();
  // Hanya yang belum bayar sama sekali. Yang sudah kirim bukti (menunggu konfirmasi) tidak dibatalkan.
  final expired = iuranList.where((i) =>
      i.isBooking &&
      i.bookingDeadline != null &&
      i.status == stBelum &&
      now.isAfter(i.bookingDeadline!)).toList();

  for (final bill in expired) {
    final room = _roomFor(bill);
    if (room != null && room.status == 'Dipesan') room.clear(); // kamar kembali kosong
    residentNotifications.insert(0, ResidentNotificationData(
      id: DateTime.now().microsecondsSinceEpoch,
      residentName: bill.residentName,
      title: 'Booking kadaluarsa',
      message: 'Booking kamar ${bill.roomNumber} dibatalkan karena belum dibayar lunas dalam 24 jam.',
      createdAt: DateTime.now(),
    ));
    iuranList.remove(bill);
  }
  if (expired.isNotEmpty && notify) notifyDataChanged();
}

// Membuat tagihan baru (booking / perpanjangan / iuran bulanan)
IuranData createIuran(
  Room r,
  String name,
  DateTime due, {
  int months = 1,
  bool booking = false,
  int extend = 0,
}) {
  final bill = IuranData(
    id: DateTime.now().microsecondsSinceEpoch,
    residentName: name,
    roomNumber: r.number,
    iuranType: booking
        ? 'Sewa $months Bulan'
        : (extend > 0 ? 'Perpanjang $extend Bulan' : 'Iuran Bulanan'),
    amount: monthlyBill(r) * months,
    dueDate: formatDate(due),
    status: stBelum,
    isBooking: booking,
    extendMonths: extend,
    bookingDeadline: booking ? DateTime.now().add(const Duration(hours: 24)) : null,
  );
  iuranList.add(bill);
  return bill;
}
